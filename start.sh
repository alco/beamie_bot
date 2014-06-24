#!/bin/sh

docker run -it -v ~/deploy_bot:/home/ircbot \
	-w="/home/ircbot" \
	-e "MIX_ENV=prod" -e "BEAMIE_BOT_PWD=$BEAMIE_BOT_PWD" \
	-e "BEAMIE_HOST=$BEAMIE_HOST" -e "BEAMIE_PORT=$BEAMIE_PORT" \
	--link beamie_eval:localhost \
	--name beamie_bot \
	alco/ubuntu-elixir:v0.14.0 iex -S mix
