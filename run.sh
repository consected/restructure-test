#!/bin/bash
# Run a container and run bash to keep the container running
# Optionally, add arguments representing an alternative command to run
# add 'interactive' to force interactive operation
# For example, to run `less` allowing user interaction:
#     ./run.sh interactive less -r output/restructure/tmp/failing_specs.log

cd -P -- "$(dirname -- "$0")"

if [ -z "$1" ]; then
  ./container-actions.sh bash
else
  ./container-actions.sh $@
fi
