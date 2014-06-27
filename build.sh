#!/bin/sh

docker run -it -v ~/public/deploys/bot:/home/proj mix_build:v0.14.1 "$@"
