#!/bin/bash
# Build a container if necessary and run one of the following by specifying it as an argument
# 
# setup-dev - setup the container with all the repos, etc for a development environment, which exits after completion
# bash - a simple command prompt that also keeps the container running
# test (or blank) - run the full test suite
#
# optionally specify 'clean' as an argument to clean up the environment and database before starting
#
# For example:
# Run the test suite
#   ./test.sh
# Setup the dev environment
#   ./test.sh setup-dev
# Run bash terminal and leave the container running 
# (VSCode can connect directly, or see the build-vars-sample.sh file for SSH details)
#   ./test.sh bash


cd -P -- "$(dirname -- "$0")"

if [ ! -s shared/.netrc ]; then
  echo "shared/.netrc file is not set up. See README.md for more info."
  exit
fi

if [ ! -s shared/build-vars.sh ]; then
  echo "shared/build-vars.sh file is not set up. See README.md for more info."
  exit
fi

if [ "$(which modprobe)" ]; then
  # This only makes sense on Linux
  modprobe fuse
  if [ $? != 0 ]; then
    echo "Failed to modprobe fuse - this is required to be installed on the host"
    exit
  fi
fi

if [ "$1" == 'clean' ] || [ "$2" == 'clean' ]; then
  docker image rm consected/restructure-test --force
  echo "If requested, sudo is required to clean up the output directories"
  sudo rm -rf output/restructure*
  sudo rm -rf output/pgsql
  sleep 5
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  docker build . -t consected/restructure-test
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  echo Container not available
else

  if [ "$1" == 'setup-dev' ] || [ "$2" == 'setup-dev' ]; then
    C_CMD="/shared/test-restructure.sh setup-dev"
    C_EXTRA_ARG='-t'
  elif [ "$1" == 'bash' ] || [ "$2" == 'bash' ]; then
    C_CMD=
    C_EXTRA_ARG='-t'
  elif [ -z $1 ] || [ "$1" == 'test' ] || [ "$2" == 'test' ]; then
    C_CMD="/shared/test-restructure.sh"
  else
    C_CMD=$1
  fi

  echo "Running container with ${C_CMD}"

  if [ "$(docker container ls -a | grep consected/restructure)" ]; then
    if [ ! "$(docker container ls | grep consected/restructure)" ]; then
      docker container start restructure-test
    fi

    if [ ${C_CMD} ]; then
      docker exec restructure-test ${C_CMD}
    else
      docker attach restructure-test
    fi
  else
    docker run -i ${C_EXTRA_ARG} \
      --name=restructure-test \
      --volume="$(pwd)/shared:/shared" --volume="$(pwd)/output:/output" \
      -p 2022:22 \
      --device /dev/fuse --privileged consected/restructure-test ${C_CMD}
  fi  
fi
