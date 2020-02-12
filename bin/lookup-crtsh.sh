#!/usr/bin/env bash

if ! (command -v md5sum)
then
  md5sum() 
  {
    md5 -r "$1"
  }
fi


echo '[i] Checking for requirements'
if ! (command -v pup)
then
  echo '[!] For html processing you need to install pup'
  echo ' github.com/ericchiang/pup/releases'
  exit 1
fi

target="${1:-.example.com}"
slug=$(echo "$target" | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr '[:upper:]' '[:lower:]')
output_dir=$(mktemp -d -t "crtsh-${slug}-XXXXXXX")

echo "[i] Checking crt.sh for target $target $slug"
domains=$(curl -s  "https://crt.sh/?q=%25${target}" | pup 'tr td:nth-child(5) text{}' | sort | uniq | grep -v '\*')
echo '['
while read -r url
do
  if [[ "$url" = *"*"* ]]; then
    echo "[!] has wildcard ... ${url}"
    continue
  fi
  slug=$(echo "$url" | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr '[:upper:]' '[:lower:]')
  output="${output_dir}/${slug}.html"
  response=$(curl -i -s -L -k --connect-timeout 2 "$url" | tee "$output" )
  status_code=$(grep 'HTTP/1.1' "$output" | tail -n1 | cut -d' ' -f2)
  hash_sum=$(md5sum "$output" | cut -d' ' -f1)
  title=$(echo "$response" | pup 'title text{}' | tr -s ' ') # egrep -iPo '(?<=<title>)(.*)(?=</title>)'
  size=$(printf "%2d"  ${#response})
  printf '{\n  "url":"%s",\n  "code":%s,\n  "title":"%s",\n  "size":%s,\n  "file":"%s"\n},\n' \
             "$url" "$status_code" "$title" "$size" "$output"
done <<< "$domains"
echo ']'
