defmodule Evaluator do
  def eval(expr, opts \\ []) do
    lang = Keyword.get(opts, :lang, "elixir")
    version = Keyword.get(opts, :version)

    hostname = System.get_env("BEAMIE_HOST")
    port = System.get_env("BEAMIE_PORT")

    if hostname != "" and port != "" do
      url = 'http://#{hostname}:#{port}/eval/#{lang}/#{version}'
      result = :httpc.request(:post, {url, [], '', expr}, [], [sync: true])
      process_result(result)
    else
      IO.puts "Broken env"
      IO.puts "BEAMIE_HOST=#{hostname}"
      IO.puts "BEAMIE_PORT=#{port}"
      "*internal service error*"
    end
  end

  defp process_result({:error, _reason}) do
    IO.inspect _reason
    "*internal service error*"
  end

  defp process_result({:ok, {status, _headers, data} }) do
    IO.inspect status
    reply = data |> List.to_string |> String.strip
    IO.puts "replying with #{reply}"
    reply
  end

  def _eval(expr) do
    try do
      {result, _} = expr |> String.strip |> Code.eval_string
      inspect(result)
    catch
      kind, error ->
        format_error(kind, error, System.stacktrace)
    end
  end

  defp format_error(:error, exception, stacktrace) do
    { exception, _ } = normalize_exception(exception, stacktrace)
    "** (#{inspect exception.__record__(:name)}) #{exception.message}"
  end

  defp format_error(kind, reason, _) do
    "** (#{kind}) #{inspect(reason)}"
  end

  defp normalize_exception(:undef, [{ IEx.Helpers, fun, arity, _ }|t]) do
    { RuntimeError[message: "undefined function: #{format_function(fun, arity)}"], t }
  end

  defp normalize_exception(exception, stacktrace) do
    { Exception.normalize(:error, exception), stacktrace }
  end

  defp format_function(fun, arity) do
    cond do
      is_list(arity) ->
        "#{fun}/#{length(arity)}"
      true ->
        "#{fun}/#{arity}"
    end
  end
end
