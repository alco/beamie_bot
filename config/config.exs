use Mix.Config

config :ircbot,
  evalhost: {System.get_env("BEAMIE_HOST"), System.get_env("BEAMIE_PORT")}

