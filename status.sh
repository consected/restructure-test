#!/bin/bash
# Get status of container or image

CONTAINER_NAME=${USER}-restructure-test

if [ "$(docker container ls --filter "name=${CONTAINER_NAME}" -q)" ]; then
  echo 'running'
elif [ "$(docker container ls -a --filter "status=exited" --filter "status=created" --filter "name=${CONTAINER_NAME}" -q)" ]; then
  echo 'stopped'
elif [ "$(docker container ls -a --filter "name=${CONTAINER_NAME}" -q)" ]; then
  echo 'other'
elif [ "$(docker image ls consected/restructure-test -q)" ]; then
  echo 'image only'
else
  echo 'nothing'
fi
