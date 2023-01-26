#!/bin/bash
# Build a container if necessary and run one of the following by specifying it as an argument
#
# setup-dev - setup the container with all the repos, etc for a development environment, which exits after completion
# bash - a simple command prompt that also keeps the container running
# test (or blank) - run the full test suite
#
# optionally specify 'clean' as an argument to clean up the containers, source code and database before starting
# or 'clean-output' to just clean the source code and database
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
script_args="$@"

function has_arg() {
  for i in ${script_args}; do
    if [ "$1" == "${i}" ]; then
      echo ${i}
      return 0
    fi
  done
  return 1
}

function args_excluding() {
  local new_args=''
  for i in ${script_args}; do
    if ! [[ "${i}" == +($1) ]]; then
      new_args="${new_args}${i} "
    fi
  done
  echo ${new_args}
}

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

if has_arg 'clean' || has_arg 'clean-only'; then
  echo 'Clean has been requested - will start in 5 seconds - Ctrl-C to exit now'
  sleep 5
  docker container rm restructure-test --force
  docker image rm consected/restructure-test --force
  sleep 5

  if has_arg 'clean-only'; then
    echo 'clean "only" completed'
    exit
  fi
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  docker build . -t consected/restructure-test
fi

if [ -z "$(docker images | grep consected/restructure-test)" ]; then
  echo Container not available
else

  C_EXTRA_ARG='-t'
  if has_arg 'setup-dev'; then
    echo 'Setup dev'
    C_CMD="/shared/test-restructure.sh setup-dev"
    CAN_CLEAN=true
  elif has_arg 'bash'; then
    echo 'Execute bash'
    C_CMD=/shared/run-dev.sh
  elif [ -z "$(args_excluding 'clean|clean-output')" ] || has_arg 'test'; then
    echo 'Run parallel test suite'
    C_CMD="/shared/test-restructure.sh test"
    CAN_CLEAN=true
    unset C_EXTRA_ARG
  elif has_arg 'interactive'; then
    C_CMD="$(args_excluding 'clean|clean-output|interactive')"
    echo "Execute alternative command interactively: ${C_CMD}"
  else
    C_CMD="$(args_excluding 'clean|clean-output')"
    echo "Execute alternative command: ${C_CMD}"
    unset C_EXTRA_ARG
  fi

  if [ "${CAN_CLEAN}" ]; then
    if has_arg 'clean' || has_arg 'clean-output'; then
      C_CMD="${C_CMD} clean-output"
    fi
  fi

  MUST_RUN=true

  # Does a container exist? If not, we must run it
  STATUS=$(./status.sh)
  if [ "${STATUS}" == 'running' ] || [ "${STATUS}" == 'stopped' ] || [ "${STATUS}" == 'other' ]; then

    unset MUST_RUN
    if [ "${STATUS}" == 'stopped' ]; then
      # A container exists but is not started: we must start it
      echo "Starting container"
      docker container start restructure-test

      while [ "$(./status.sh)" == 'stopped' ]; do
        sleep 2
        echo "Waiting for container to start"
      done
    fi

    # In the running container, execute a command if one has been specified, otherwise just attach to the container
    if [ "${C_CMD}" ]; then
      echo "Executing command in running container: ${C_EXTRA_ARG} ${C_CMD}"
      docker exec -i ${C_EXTRA_ARG} restructure-test ${C_CMD}
    else
      echo "Attaching to running container"
      docker attach restructure-test
    fi

  fi

  if [ "${MUST_RUN}" ]; then
    # Run the container from the image consected/restructure-test, and call the specified command
    echo "Running container because it is not yet running: $(./status.sh)"
    # ${C_EXTRA_ARG}
    docker run -dt \
      --name=restructure-test \
      -p 127.0.0.1:2022:22 -p 127.0.0.1:13000:3000 -p 127.0.0.1:15432:5432 \
      --device /dev/fuse \
      --cap-add SYS_ADMIN \
      consected/restructure-test

    RES=$?
    if [ $? != 0 ]; then
      echo 'Failed to run container'
      echo "Result: ${RES}"
      exit 7
    fi

    while [ "$(./status.sh)" != 'created' ] && [ "$(./status.sh)" != 'running' ]; do
      sleep 2
      echo "Waiting for run to complete: $(./status.sh)"
    done

    ./container-actions.sh $(args_excluding 'clean')
    # --volume="$(pwd)/shared:/shared" --volume="$(pwd)/output:/output" \
  fi
fi
