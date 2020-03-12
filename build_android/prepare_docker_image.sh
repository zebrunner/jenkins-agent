#!/bin/bash
set -xe
docker build -t android_container:qps --file Dockerfile .
