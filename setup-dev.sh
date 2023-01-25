#!/bin/bash
# Build a container and set up the dev environment
# Optionally clean the output directories (source and DB) before running, with the argument 'clean'

cd -P -- "$(dirname -- "$0")"

if [ "$1" == clean ]; then
  CLEANARG=clean
fi

./container-actions.sh setup-dev ${CLEANARG}
