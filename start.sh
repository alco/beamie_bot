#!/bin/sh

set -e

BEAMIE_HOST=${BEAMIE_HOST-localhost}
BEAMIE_PORT=${BEAMIE_PORT-8000}

docker rm beamie_bot || true
docker run -it -v ~/public/deploys/bot:/home/proj \
	-e "BEAMIE_BOT_PWD=$BEAMIE_BOT_PWD" \
	-e "BEAMIE_HOST=$BEAMIE_HOST" \
	-e "BEAMIE_PORT=$BEAMIE_PORT" \
	--link beamie_eval:localhost \
	--name beamie_bot \
	mix_build:v0.15.1 iex -S mix
