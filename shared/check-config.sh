#!/bin/bash
# Simple script for keeping a container running when it is started
# assuming that `docker container start -i <container>` specified -i for interactive.
# This allows the start to also be run without -i and not block

source /shared/build-vars.sh
source /shared/setup-dev-env.sh
echo 'Running check-config.sh and keeping bash running'
if [ -z $1 ]; then
  /bin/bash
else
  $@
fi
