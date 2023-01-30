#!/bin/bash
# Simply stop the running container
CONTAINER_NAME=${USER}-restructure-test
echo "Stopping container: ${CONTAINER_NAME}"
docker container stop ${CONTAINER_NAME}
