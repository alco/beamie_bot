use Mix.Config

config :chatty,
  nickname: "beamie_testbot",
  channels: ["test-secret-channel"]
  #nickname: "beamie",
  #channels: ["elixir-lang", "erlang-lisp"],

config :logger, console: [
  level: :debug,
]

config :logger, [
  handle_otp_reports: true,
  handle_sasl_reports: false,
]
