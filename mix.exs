defmodule Ircbot.Mixfile do
  use Mix.Project

  def project do
    [ app: :ircbot,
      version: "0.0.1",
      elixir: "~> 0.14.0",
      deps: deps ]
  end

  def application do
    [mod: { Ircbot, [] },
     applications: [:inets, :crypto, :ssl]]
  end

  defp deps do
    []
  end
end
