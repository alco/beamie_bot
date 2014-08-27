#!/bin/sh

set -e

docker run -it --rm -v ~/public/deploys/bot:/home/proj mix_build:v0.15.1 "$@"
