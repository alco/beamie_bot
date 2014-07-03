defmodule BeamieBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :beamie_bot,
      version: "0.1.0",
      elixir: "~> 0.14.1",
      deps: deps
    ]
  end

  def application do
    [mod: { BeamieBot, [] },
     applications: [:inets, :crypto, :ssl, :chatty]]
  end

  defp deps do
    [{:chatty, github: "alco/chatty"}]
  end
end
