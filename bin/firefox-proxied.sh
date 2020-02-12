#!/usr/bin/env bash

# @todo have a named profile that can be re-used
# @todo start up proxy if not running
set -e

FF_DIR=$(dirname $(readlink -f $(command -v firefox)))
PROXY_IGNORE_DEF=(
  'mozilla.com'
  'mozilla.org'
  'mozilla.net'
  'firefox.com'
  'google-analytics.com'
  'google.com'
  'gmail.com'
  'gstatic.com'
  'googleapis.com'
  'googleusercontent.com'
  'localhost'
  '127.0.0.1'
)
OIFS="$IFS"
IFS=","
PROXY_IGNORE_DEF="${PROXY_IGNORE_DEF[*]}"
IFS="$OIFS"

trap on_sigint INT

on_sigint() 
{
  echo '[i] Caught SIGINT (ctrl-c)'
  cleanup
}

cleanup()
{
  echo "[i] Cleaning up"
  local line_start
  local profile_name="${FF_PROXY_PROFILE}"
  local default_pref="${FF_DIR}/defaults/pref/proxy.js"

  # Clean up profile configs if created custom profile
  if [ -f "${FF_DIR}/_proxy-cert.cfg" ]
  then
    echo "[i] Cleaning up profile ${profile_name}"
    sudo bash -c "rm ${FF_DIR}/defaults/pref/proxy.js;rm ${FF_DIR}/_proxy-cert.cfg"
    rm -rf "/tmp/firefox-${profile_name}"
    line_start=$(grep -n -B1 "Name=${profile_name}"  ~/.mozilla/firefox/profiles.ini | head -n1 | cut -d'-' -f1)
    sed -i "$line_start,+4d" ~/.mozilla/firefox/profiles.ini 
  fi
}

update_prefs()
{
  local profile_name="${FF_PROXY_PROFILE}"
  local proxy_host="${FF_PROXY}"
  local proxy_port="${FF_PROXY_PORT}"
  local profile_prefs="/tmp/firefox-${profile_name}/prefs.js"
  local proxy_ignore="${PROXY_IGNORE:-$PROXY_IGNORE_DEF}"
  touch "${profile_prefs}"

  cat >"${profile_prefs}" << EOF
// https://dxr.mozilla.org/mozilla-release/source/modules/libpref/init/all.js
// user_pref('network.proxy.autoconfig_url', '${proxy_host}');
user_pref('network.proxy.http', '${proxy_host}');
user_pref('network.proxy.http_port', ${proxy_port});  
user_pref('network.proxy.no_proxies_on', '$proxy_ignore');
user_pref("network.proxy.socks", '${proxy_host}');
user_pref("network.proxy.socks_port", ${proxy_port});
user_pref("network.proxy.ssl", '${proxy_host}');
user_pref("network.proxy.ssl_port", ${proxy_port});
user_pref('network.proxy.type', 1);
user_pref("network.proxy.share_proxy_settings", true);
// user_pref('network.proxy.ssl', "10.10.10.200")
// user_pref('network.proxy.ssl_port', ${proxy_port});
user_pref("app.normandy.first_run", false);
user_pref("app.update.enabled", false); 
user_pref('browser.startup.homepage', 'about:blank');
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.formfill.enable", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.prerender", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("security.OCSP.enabled", 0);
user_pref("security.enterprise_roots.enabled", true);
user_pref("ssecurity.ssl.enable_ocsp_must_staple", false);
user_pref("security.ssl.enable_ocsp_stapling", false);
user_pref("browser.ssl_override_behavior", 2);
user_pref("browser.xul.error_pages.expert_bad_cert", true);
user_pref("update_notifications.enabled", false);
user_pref("security.ssl.errorReporting.enabled", false);
user_pref("network.stricttransportsecurity.preloadlist", false);
user_pref("security.ssl.errorReporting.url", "http://localhost");
EOF
}

import_cert_script()
{
  # http://xulfr.org/forums/forum/1/8256
  # https://mike.kaply.com/2015/02/10/installing-certificates-into-firefox/
  # @todo make look for cert file
  local cert_data="$1"
  cat >/tmp/_proxy-cert.cfg << EOF
var Cc = Components.classes;
var Ci = Components.interfaces;
var certdb = Cc["@mozilla.org/security/x509certdb;1"].getService(Ci.nsIX509CertDB);
var certdb2 = certdb;
try {
  certdb2 = Cc["@mozilla.org/security/x509certdb;1"].getService(Ci.nsIX509CertDB2);
} catch (e) {}
cert="${cert_data}"
// This should be the certificate content with no line breaks at all.
certdb.addCertFromBase64(cert, "C,C,C", "");
EOF

  sudo mv /tmp/_proxy-cert.cfg "${FF_DIR}/_proxy-cert.cfg"
}


import_proxy_certs()
{
  # @todo improve for BURP
  # https://stackoverflow.com/questions/37553127/is-it-possible-to-automatically-import-certificates-in-firefox
  # https://firstyear.id.au/blog/html/2014/07/10/NSS-OpenSSL_Command_How_to:_The_complete_list..html
  # sudo apt-get install -y libnss3-tools
  # export NSS_DEFAULT_DB_TYPE=sql
  local cert_data=""
  local default_pref="${FF_DIR}/defaults/pref/proxy.js"

  if [ -f "${FF_PROXY_CERT}" ]
  then
    echo '[i] Found cert in env ... ${FF_PROXY_CERT}'
    cert_data=$(cat "${FF_PROXY_CERT}" | grep -v CERTIF | tr -d '\n')
  elif (curl -s "http://${proxy_host}:${proxy_port}/JSON/core/view/version/?zapapiformat=JSON")
  then
    echo
    echo '[i] Running proxy is ZAP ... getting cert'
    cert_data=$(curl -s  "http://${FF_PROXY}:${FF_PROXY_PORT}/OTHER/core/other/rootcert/?formMethod=GET" | grep -v CERTIF | tr -d '\n')
  fi

  if [ -z "${cert_data}" ]
  then
    echo '[i] No certificate to import'
    return
  fi

  echo '[i] Importing certificate'
  import_cert_script "${cert_data}"

  {
    echo '// Any comment. You must start the file with a comment';
    echo 'pref("general.config.filename", "_proxy-cert.cfg");'; 
    echo 'pref("general.config.obscure_value", 0);' 
  } > /tmp/proxy.js
  sudo mv /tmp/proxy.js "${default_pref}"
}

main() 
{
  local name
  local profile_name="${FF_PROXY_PROFILE}" # You can have a custom existing profile
  local proxy_host="${1:-127.0.0.1}"
  local proxy_port="${2:-8080}"

  if [ -z "${profile_name}" ]
  then
    echo '[i] Creating custom profile for proxy'
    name=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    profile_name="proxy-$name"
    # https://developer.mozilla.org/en-US/docs/Mozilla/Command_Line_Options#User_Profile
    firefox -no-remote  -CreateProfile "${profile_name} /tmp/firefox-${profile_name}"
  else
    echo "[i] Using existing profile for proxy"
  fi

  export FF_PROXY_PROFILE="${profile_name}"
  export FF_PROXY="${proxy_host}"
  export FF_PROXY_PORT="${proxy_port}"

  update_prefs "${profile_name}" "${proxy_host}" "${proxy_port}" 
  import_proxy_certs
  
  if ! (curl -s -o /dev/null -f "${proxy_host}:${proxy_port}")
  then
    echo "[!] That proxy is dead? ${proxy_host}:${proxy_port}"
    return 1
  fi


  firefox -P "${profile_name}" 
  cleanup
}

# Get sudo prompt out of the way 
sudo whoami

main "$1"