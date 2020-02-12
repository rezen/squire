#!/bin/bash

# Support for mac or debian
# @todo run all commands in screen/tmux/terminal tab
# @todo locks to prevent command from running again for same target
# @todo overwrite reports by default, using git for each reports repo
export SCANS_BINS="$HOME/bin/"
export SCANS_DATA_DIR="$HOME/scans/"
export HTTP_DEFAULT_TIMEOUT=3
export PROXY_HOST=127.0.0.1
export PROXY_PORT=8080
export REPOS_DIR="$HOME/vcs/"

slug()
{
    echo "$1" |  sed -E 's|https?://||g;s|[^a-zA-Z0-9]|-|g'
}

setup-deps()
{
    local equired=(git docker curl python rl jq pup)
    for cmd in "${required[@]}"
    do
        if ! (command -v "${cmd}" > /dev/null)
        then
            echo "[!] Missing required - $cmd"
            if [ `uname` == 'Darwin' ]
            then
                brew install randomize-lines pup coreutils loc
            fi
            exit 1
        fi
    done
}

list-tools()
{
    echo
}

list-tools-appsec()
{
    echo
}

list-tools-code()
{
    echo
}

setup-repos()
{
    local repos=(
        github.com/sqlmapproject/sqlmap
        github.com/commixproject/commix
        github.com/lanjelot/patator
        github.com/nccgroup/ScoutSuite
        github.com/xmendez/wfuzz
        github.com/erwanlr/Fingerprinter
        github.com/codingo/NoSQLMap
        github.com/arthepsy/ssh-audit
        github.com/D35m0nd142/LFISuite
        github.com/utiso/dorkbot
        github.com/xmendez/wfuzz
        github.com/urbanadventurer/WhatWeb
    )

    for repo in "${repos[@]}"
    do
        (cd "$REPOS_DIR" && git clone "https://${repo}.git" > /dev/null) || echo "[i] Already cloned - ${repo}"
    done
}

setup-dirs() 
{
    if [ ! -d "${SCANS_BINS}" ]
    then
        mkdir -p "${SCANS_BINS}"
    fi

    if [ ! -d "$SCANS_DATA_DIR" ]
    then
        mkdir -p "$SCANS_DATA_DIR/_lists"
    fi

    if [ ! -d "$REPOS_DIR" ]
    then
        mkdir -p "$REPOS_DIR"
    fi
}

setup-deps
setup-dirs
setup-repos

timestamp()
{
    echo `date '+%Y%m%d%H%M%S'`
}

browser-open()
{   
    url="$1"
    # sensible-browser, xdg-open, gnome-open
    if (command -v open > /dev/null)
    then
        open "${url}"
    elif (command -v sensible-browser > /dev/null)
    then
        sensible-browser "${url}"
    else
        echo "[!] Ruh-roh, no browser?"
    fi
}

url-to-domain()
{
    local target="$1"
    echo "${target}" | cut -d'/' -f3
}

url-data-dir()
{
    # Make sure there is a folder for the domain & create a subfolder for the specific path
    local target="$1"
    local dir=$(echo "$target" |  sed -E 's|https?://||g;s|[^a-zA-Z0-9]|-|g')
    local domain=$(url-to-domain "$target")
    local trailing=$(echo "${target}" | cut -d'/' -f4- | sed -E 's|\/$||g;s|[^a-zA-Z0-9]|-|g;')
    dir=${dir%/}
    mkdir -p "${SCANS_DATA_DIR}${domain}/${trailing}"
    echo "${SCANS_DATA_DIR}${domain}/${trailing}"
}

url-tech()
{
    # With one request ...
    # Does basic header checks & body greps to guess tech, probably should be written python/golang
    local target="$1"
    local tmpf=$(mktemp)
    local headers=$(curl -sSL -D - "$target" -o "$tmpf")
    local server=$(echo "$headers" | grep -i 'server:' | cut -d' ' -f2)
    local powered_by=$(echo "$headers" | grep -i 'x-powered' | cut -d' ' -f2)

    if grep -q '.php' "$tmpf"
    then
        echo '[i] May be using php'
    elif grep -q 'cgi-bin' "$tmpf"
    then
        echo '[i] May be using perl'
    elif grep -q 'wp-content' "$tmpf"
    then
        echo '[i] Using WordPress'
        return
    fi

    if [ "$server" == *"Apache"* ]
    then
        echo '[i] Using Apache'
    elif [ "$server" == *"nginx"* ]
    then
        echo '[i] Using nginx'
    fi
}

is-url-live()
{
    local target="$1"
    if (curl -s -L --max-time 3.0 "$target" > /dev/null)
    then
        return 0
    fi
    echo "[!] Url does not appear to be alive - $target"
    return 1
}

is-proxy_live()
{
    if ! (curl -s -o /dev/null -f "${PROXY_HOST}:${PROXY_PORT}")
    then
        echo "[!] That proxy is dead? ${PROXY_HOST}:${PROXY_PORT}"
        return 1
    fi
    return 0
}

lookup-ip()
{
    local target="$1"
}

lookup-domain()
{
    local target="$1"
    whois "$target"
}

lookup-certs()
{
    local target="$1"
    browser-open "https://crt.sh/?q=${target}&dir=v&sort=4&group=none"
    browser-open "https://www.ssllabs.com/ssltest/analyze.html?d=${target}&hideResults=on&latest"
}

lookup-md5()
{
    # 0192023a7bbd73250516f069df18b500
    local hash="$1"
    browser-open "https://www.md5reverse.com/${hash}"
    browser-open "https://www.md5online.org/md5-decrypt.html"
    browser-open "http://hashtoolkit.com/reverse-hash/?hash=${hash}"
}

scan-nikto()
{
    local target="$1"
    if ! (command -v docker)
    then
        echo "[i] Must install docker"
        return 1
    fi
    local output=$(url-data-dir "$target")
    # @todo -proxy localhost:8080
    docker run --rm --network host -v "${output}":/report frapsoft/nikto \
        -host "$target" \
        -timeout "$HTTP_DEFAULT_TIMEOUT"  \
        -o "/report/nikto.csv"
}

scan-wpscan()
{
    local target="$1"
    if ! (command -v docker)
    then
        echo "[i] Must install docker"
        return 1
    fi
    local output=$(url-data-dir "$target")
    # @todo --proxy protocol://IP:port  
    docker run --rm --network host -v "${output}":/report wpscanteam/wpscan \
        --url "${target}" \
        --enumerate \
        --connect-timeout 3 \
        --disable-tls-checks \
        --plugins-detection mixed \
        --format json \
        --output "/report/wpscan.json"
}

ensure-wfuzz()
{
    if (command -v wfuzz > /dev/null) || [ -f "${SCANS_BINS}/wfuzz" ]
    then
        return 0
    fi

    pip uninstall pycurl
    export PYCURL_SSL_LIBRARY=openssl
    pip install pycurl

    ( cd "${REPOS_DIR}/wfuzz/" && ls -lah && python setup.py install )
}

ensure-seclists()
{
    if [ -d "${REPOS_DIR}/SecLists" ]
    then
        return 0
    fi
    echo '[i] Installing seclists'
    HERE=$(pwd)
    cd "$REPOS_DIR"
    git clone https://github.com/danielmiessler/SecLists
    cd "$HERE"
}

ensure-gobuster()
{
    if (command -v gobuster) || [ -f "${SCANS_BINS}/gobuster" ]
    then
        return 0
    fi

    local version='v2.0.1'

    echo '[i] Installing gobuster'
    if [ `uname` == 'Darwin' ]
    then
        url='https://github.com/OJ/gobuster/releases/download/${version}/gobuster-darwin-amd64.7z'
    else
        url='https://github.com/OJ/gobuster/releases/download/${version}/gobuster-linux-amd64.7z'
    fi

    wget --quiet -O /tmp/gobuster.7z "$url"
    7z x /tmp/gobuster.7z -aoa -o/tmp
    mv /tmp/gobuster-*/gobuster "${SCANS_BINS}"
    chmod +x "${SCANS_BINS}/gobuster"
}

wordlist-for()
{
    local type="${1:-passwords}"
    local list_size="${2:-1000}"
    local root=$(find "${REPOS_DIR}/SecLists/" -type d -iname "$type" -maxdepth 1 | head -n1)

    if [ ! -d "${root}" ]
    then
        echo '[!] Found nothing matching'
        return 1
    fi
    # Will randomize finding ... 
    # @todo fallback to use wc -l if size not in filename
    local found_list=$(find "${root}" -type f  -name "*${list_size}.txt" | rl -c1)

    if [ ! -f "$found_list" ]
    then
        echo "[!] Found nothing matching"
        return 2
    fi
    echo $found_list
}

wordlist-generate()
{
    local start="$1"
    local slugified=$(slug "$start")
    local wordlist_file="$SCANS_DATA_DIR/_lists/${slugified}.txt"
    # https://github.com/LandGrey/pydictor
    if [ ! -d "$REPOS_DIR/pydictor" ]
    then
        git clone --depth=1 --branch=master https://www.github.com/landgrey/pydictor.git "$REPOS_DIR/pydictor"
    fi

    python "$REPOS_DIR/pydictor/pydictor.py" \
        -extend "$start" \
        --level 1 \
        --len 4 16 \
        -o "$wordlist_file"

    echo
    echo "${wordlist_file}"
}

default-list-passwords()
{
    ensure-seclists
    echo "${REPOS_DIR}/SecLists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt"
}

default-list-users()
{
    ensure-seclists
    echo "${REPOS_DIR}/SecLists/Usernames/cirt-default-usernames.txt"
}

scan-gobuster() 
{
    # @todo have multiple wordlists and continue on if find nothing in 
    # each successive one
    # @todo for each succesful url, try curl'ing through proxy
    local target="$1"
    local list="$2"
    local wordlist=(
        "${REPOS_DIR}/SecLists/Discovery/Web-Content/common.txt"
        "${REPOS_DIR}/SecLists/Discovery/Web-Content/raft-small-words-lowercase.txt"
        "${REPOS_DIR}/SecLists/Discovery/Web-Content/Common-PHP-Filenames.txt"
    )

    if [ ! -z "$list" ] && [ ! -f "$list" ]
    then
        for file in "${wordlist[@]}"
        do
            if (echo "$file" | grep -i "$list")
            then
                list="$file"
                break
            fi
        done

        if [ ! -f $list ]
        then
            list=$(find  "${REPOS_DIR}/SecLists/Discovery/Web-Content/" -type f -iname "*${list}*" | head -n1)
        fi
    else
        list="${wordlist[0]}"
    fi

    ensure-gobuster
    ensure-seclists
    
    if ! is-url-live "$target"
    then
        return 1
    fi

    # @todo change wordlist based on headers
    url-tech "$target"

    local output=$(url-data-dir "$target")

    # -p localhost:8080
    "${SCANS_BINS}/gobuster" -to "${HTTP_DEFAULT_TIMEOUT}s" \
        -u "$target" \
        -w "${list}" \
        -o "${output}/gobuster.log"
}

scan-raccoon()
{
    local target="$1"
    if ! (command -v docker)
    then
        echo "[i] Must install docker"
        return 1
    fi

    if [ ! -d "${REPOS_DIR}/raccoon" ]
    then
        git clone --depth=1 --branch=master https://github.com/evyatarmeged/Raccoon.git "$REPOS_DIR/raccoon"
    else 
        docker build -q -t evyatarmeged/raccoon "$REPOS_DIR/raccoon"
    fi

    local output=$(url-data-dir "$target")
    # @todo -proxy localhost:8080
    docker run --rm --network host \
        -v "${output}":/report evyatarmeged/raccoon:latest "$target" \
        -o "/report/raccoon/"
}