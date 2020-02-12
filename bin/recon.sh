#!/usr/bin/env bash

# https://securityonline.info/fenrir-simple-bash-ioc-scanner/
# https://www.shellcheck.net/
# https://github.com/mubix/post-exploitation/wiki/Linux-Post-Exploitation-Command-List

if ! (command -v md5sum)
then
  md5sum() 
  {
    md5 -r "$1"
  }
fi

files=()
files+=(/var/apache1/config.inc)
files+=(/var/lib/mysql/mysql/user.MYD)
files+=(/usr/local/www/apache1?/data2/httpd.conf)
files+=(/etc/resolv.conf)
files+=(/etc/sysconfig/network)
files+=(/etc/networks)

add_home_files()
{
  local home_dir="$1"
  files+=($home_dir/.bash_history)
  files+=($home_dir/.nano_history)
  files+=($home_dir/.atftp_history)
  files+=($home_dir/.mysql_history) 
  files+=($home_dir/.php_history) 
  files+=($home_dir/.python_history)
}

cat_if_exists()
{
  local file="$1"
  # local message="$2"
  local mb_max=500000

  if ! [ -f "$file" ]
  then
    echo "[-] Did not find file:$file"
    return
  fi

  echo "[+] Checking out file $file"
  filesize=$(stat -c%s "$file")
  
  if (( "$filesize" > "$mb_max" ))
  then
    # @todo output to
    echo "[!] Not outputting, too big file: ${file}"
    return
  fi

  { 
    delimiter
    cat "$file" 
    delimiter
  } ||  { 
    echo "[!] Could not open file $file" 
  }
}

delimiter()
{
  echo '-----------------------------------------------------------'
}

get_distro() 
{
  (lsb_release -a) || (cat /etc/*-release) || (cat /etc/issue)
}

get_kernel()
{
  (cat /proc/version) || (uname -a) || (uname -mrs)
}

get_current_user()
{
  whoami
}

get_users()
{
  (cut -d: -f1 /etc/passwd)
}

get_super_users()
{
  (awk -F: '($3 == "0") {print}' /etc/passwd)
}

get_last_logins()
{
  last
}

get_current_loggedin()
{
  w
}

get_files_with_root_suid()
{
  timeout 20 find / -perm -4000 2>/dev/null
}

get_process_hashes() 
{
  list=$(ps x |  sed -e 's/^[ \t]*//' | tr -s ' ' | cut -d' ' -f5 | sort | uniq)
  while read -r line; do
    if [ -f "$line" ]
    then
      md5sum "$line"
    else
      bin_path=$(command -v "$line")

      if [ -z "$bin_path" ]
      then
        printf ' %.0s' {1..34}
        printf "?\n"
      else
        md5sum "$bin_path"
      fi
    fi
  done <<< "$list"
}

get_external_ip()
{
  (curl ipinfo.io/ip)
}

get_internal_ip()
{
  (ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
}

get_interesting_files()
{
  # To get all users home folders
  # cut -d':' -f6 /etc/passwd
  for user in $(ls /home)
  do
    if [ -d "/home/${user}" ]
    then
      add_home_files "/home/${user}"
    fi
    files+=("/var/mail/$user")
  done

  if [ "$EUID" -eq 0 ]
  then
    add_home_files /root/
  fi

  for file in "${files[@]}"
  do
    cat_if_exists "$file" 
  done
}

run_commands()
{
  local timeout_secs=10
  OIFS=$IFS
  IFS=$'\n'
  commands=(
    'get_distro'
    'get_kernel'
    'get_users'
    'get_super_users'
    'get_last_logins'
    'get_current_user'
    'get_current_loggedin'
    'get_interesting_files'
    'get_files_with_root_suid'
    'ls -lAh /tmp/'
    'ls -lAh /dev/shm'
    'find /etc/cron* -type f'
    'crontab -l | grep "^[^#;]"'
    'ps auxw'
    'get_process_hashes'
    'get_external_ip'
    'get_internal_ip'
    'netstat --inet 4'
    'netstat -tulpn'
    'lsof -nPi'
    'arp -a'
  )
  IFS=$OIFS

  for command in "${commands[@]}"
  do
    # eval "declare -F $command" || echo "Function not found"
    command_bin=$(echo "$command" | cut -d' ' -f1)
    if ! (command -v "$command_bin" > /dev/null)
    then
      echo "[-] Could not find the bin: $command_bin"
      continue
    fi
    delimiter
    echo "[i] Running command: $command"
    delimiter

    if (command -v timeout > /dev/null) && [[ "${command}" = *" "* ]]
    then
      (eval "timeout ${timeout_secs} ${command}")
    else
      (eval "${command}")
    fi    
  done
}

time run_commands