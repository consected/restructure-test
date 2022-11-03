#!/bin/bash
# Build a container if necessary and run the app build

cd -P -- "$(dirname -- "$0")"

echo > shared/build_version.txt

if [ ! -s shared/.netrc ]; then
  echo "shared/.netrc file is not set up. See README.md for more info."
  exit
fi

if [ ! -s shared/build-vars.sh ]; then
  echo "shared/build-vars.sh file is not set up. See README.md for more info."
  exit
fi

if [ "$1" == 'clean' ]; then
  docker image rm consected/restructure-build --force
  sleep 5
fi

if [ -z "$(docker images | grep consected/restructure-build)" ]; then
  docker build . -t consected/restructure-build
fi

if [ -z "$(docker images | grep consected/restructure-build)" ]; then
  echo Container not available
else
  docker run --volume="$(pwd)/shared:/shared" --volume="$(pwd)/output:/output" consected/restructure-build
fi
