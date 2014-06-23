defmodule Evaluator do
  def eval(expr, opts \\ []) do
    lang = Keyword.get(opts, :lang, "elixir")
    version = Keyword.get(opts, :version)
    result = :httpc.request(:post, {'http://localhost:8000/eval/#{lang}/#{version}', [], '', expr}, [], [sync: true])
    case result do
      {:error, _reason} ->
        IO.inspect _reason
        "*internal service error*"
      {:ok, {status, _headers, data} } ->
        IO.inspect status
        reply = data |> List.to_string |> String.strip
        IO.puts "replying with #{reply}"
        reply
    end
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
