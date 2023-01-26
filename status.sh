#!/bin/bash
# Get status of container or image

if [ "$(docker container ls --filter "name=restructure-test" -q)" ]; then
  echo 'running'
elif [ "$(docker container ls -a --filter "status=exited" --filter "status=created" --filter "name=restructure-test" -q)" ]; then
  echo 'stopped'
elif [ "$(docker container ls -a --filter "name=restructure-test" -q)" ]; then
  echo 'other'
elif [ "$(docker image ls consected/restructure-test -q)" ]; then
  echo 'image only'
else
  echo 'nothing'
fi
