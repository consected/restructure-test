#!/bin/bash
# Build a container and run the test suite
# Optionally clean the output directories (source and DB) before running, with the argument 'clean'

cd -P -- "$(dirname -- "$0")"

if [ "$1" == clean ]; then
  CLEANARG=clean-output
elif [ "$1" == rebuild ]; then
  ./container-actions.sh echo clean
  exit
fi

./container-actions.sh test ${CLEANARG}
