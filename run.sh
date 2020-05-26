#!/bin/bash
app="mygoapp"
docker container rm -f ${app}
docker build -t ${app} .
docker run -d -p 8080:8080 \
  --name=${app} \
  -v $PWD/logs/go-docker:/app/logs ${app}