#!/bin/bash
# Clean containers and images
# Must specify 'only' or 'rebuild' as an argument to run this command to clean the existing containers and images

cd -P -- "$(dirname -- "$0")"

if [ "$1" == only ]; then
  ./container-actions.sh clean-only
elif [ "$1" == rebuild ]; then
  ./container-actions.sh echo clean
else
  echo 'Specify an argument to run the clean command'
fi
