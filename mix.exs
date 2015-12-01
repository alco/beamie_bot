defmodule BeamieBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :beamie_bot,
      version: "0.6.0",
      elixir: "~> 1.0",
      deps: deps
    ]
  end

  def application do
    [
      mod: {BeamieBot, []},
      applications: [:logger, :inets, :crypto, :ssl, :chatty]
    ]
  end

  defp deps do
    [
      {:chatty, github: "alco/chatty"},
      {:poison, "~> 1.5.0"}
    ]
  end
end
