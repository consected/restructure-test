#!/bin/bash
# Build a container if necessary and run the app build

cd -P -- "$(dirname -- "$0")"

if [ ! -s shared/.netrc ]; then
  echo "shared/.netrc file is not set up. See README.md for more info."
  exit
fi

if [ ! -s shared/build-vars.sh ]; then
  echo "shared/build-vars.sh file is not set up. See README.md for more info."
  exit
fi

modprobe fuse
if [ $? != 0 ]; then
  echo "Failed to modprobe fuse - this is required to be installed on the host"
  exit
fi

if [ "$1" == 'clean' ]; then
  docker image rm consected/restructure-test --force
  sudo rm -rf output/restructure*
  sleep 5
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  docker build . -t consected/restructure-test
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  echo Container not available
else
  docker run --volume="$(pwd)/shared:/shared" --volume="$(pwd)/output:/output" \
    --device /dev/fuse --privileged consected/restructure-test
fi
