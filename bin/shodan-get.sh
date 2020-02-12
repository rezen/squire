#!/bin/bash

query="$1"
now=$(date '+%Y%m%d%H%M%S')
archived="search-$now"


if [ -z "$query" ]
then
  echo "[!] Pass a query"
  exit 0
fi
count=$(shodan count "$query")

echo "[i] Found $count result(s) searching for: $query"

if [ "$count" -eq 0 ]
then 
  echo "[!] No results, will not proceed"
  exit 1
fi


if !(command -v jq)
then
  echo '[!] You need jq installed'
  exit 2
fi

shodan download "$archived" "$query" --limit=-1

touch "hosts-info-$now"
echo "[i] Hosts detailed info will be saved to hosts-info-$now"
zcat "$archived.json.gz" | jq '.ip_str' | cat | tr -d '"' | xargs -I{} shodan host {} >> "hosts-info-$now"

echo '[i] Listing unique ports/services'
cat "hosts-info-$now" | egrep '[0-9]+/(tc|ud)p' | tr -s ' ' | cut -d' ' -f2 | sort | uniq -c
