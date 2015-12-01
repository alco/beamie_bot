defmodule Evaluator do
  @moduledoc """
  This module is designed to work the beamie_eval project which has not yet
  been released publicly.
  """

  def eval(expr, opts \\ []) do
    lang = Keyword.get(opts, :lang, "elixir")
    version = Keyword.get(opts, :version)

    hostname = System.get_env("BEAMIE_HOST")
    port = System.get_env("BEAMIE_PORT")

    if hostname != "" and port != "" do
      url = 'http://#{hostname}:#{port}/eval/#{lang}/#{version}'
      result = :httpc.request(:post, {url, [], '', expr}, [timeout: 3000], [sync: true])
      process_result(result)
    else
      IO.puts "Broken env"
      IO.puts "BEAMIE_HOST=#{hostname}"
      IO.puts "BEAMIE_PORT=#{port}"
      "*internal service error*"
    end
  end

  defp process_result({:error, reason}) do
    IO.inspect reason
    "*internal service error*"
  end

  defp process_result({:ok, {status, _headers, data} }) do
    IO.inspect status
    reply = data |> IO.iodata_to_binary |> String.strip
    IO.puts "replying with #{reply}"
    reply
  end
end
