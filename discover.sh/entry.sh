#!/bin/bash

trap 'killall' INT

# alias firefox="echo"

killall() 
{
  trap '' INT TERM 
  echo '*********** [!] discover.sh shutting down **************'
  kill -TERM 0
  wait
  echo '*********** [!] discover.sh dead **************'
}

./discover.sh

echo '*********** discover.sh done **************'
sleep 120

