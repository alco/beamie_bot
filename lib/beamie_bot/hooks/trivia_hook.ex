defmodule TriviaHook do
  @moduledoc """
  Scan a message for certain word patterns and send messages accordingly.
  """

  @evm_replies [
    "there is no such thing as EVM",
    "what is EVM? Exceptionally Visual Monitoring?",
    "EVM is a lie",
    "what's an EVM? an Emotionally Variadic Method?",
  ]

  def run(_sender, text) do
    tokens = tokenize(text)
    result = cond do
      find_at_least(tokens, [
        {["mix", "project", "application", "app"], 1},
        {["shell", "iex", "repl"], 1},
        {["?"], 1}]) ->
          "To start an interactive shell with your mix project loaded in it, run `iex -S mix`"

      find_at_least(tokens, [
        {["mix"], 1},
        {["hex"], 1},
        {["replace", "replaces"], 1},
        {["?"], 1}]) ->
          "hex does not replace mix, it augments it"

      find_at_least(tokens, [
        {["elixir"], 1},
        {["package", "packages", "npm", "gem", "gems", "bundler"], 1},
        {["?"], 1}]) ->
          {:msg, msg} = LinkHook.run(_sender, "hex")
          msg

      find_at_least(tokens, [
        {["evm"], 1},
        {["?"], 1}]) ->
          random_from(@evm_replies)

      find_at_least(tokens, [
        {["beamie"], 1},
        {["actor"], 1},
        {["model"], 1}]) ->
          get_gosling_link()

      true -> nil
    end
    result && {:msg, result}
  end

  def random_from(list, count \\ 0) do
    if count == 0, do: count = length(list)
    Enum.at(list, :random.uniform(count)-1)
  end

  def tokenize(text) do
    Regex.split(~r"[[:space:]]|\b", String.downcase(text), trim: true)
  end

  def find_at_least(tokens, pairs) do
    count = process_pairs(pairs, tokens, 0)
    count == length(pairs)
  end

  defp process_pairs([], _, count), do: count

  defp process_pairs([{terms, tc}|t], tokens, count) do
    processed_count = process_terms(terms, tokens, tc)
    process_pairs(t, tokens, count + processed_count)
  end

  defp process_terms(_, _, 0), do: 1

  defp process_terms([], _, _), do: 0

  defp process_terms([word|t], tokens, count) do
    sub = if Enum.member?(tokens, word), do: 1, else: 0
    process_terms(t, tokens, count - sub)
  end


  defp get_gosling_link() do
    url = 'http://programmerryangosling.tumblr.com/random'
    result = :httpc.request(:head, {url, []}, [], [sync: true])
    case result do
      {:error, _reason} ->
        IO.inspect _reason
        nil
      {:ok, {status, headers, _data} } ->
        #IO.inspect status
        #IO.inspect headers
        case status do
          {_, 301, _} ->
            new_url =
              List.keyfind(headers, 'location', 0)
              |> elem(1)
              |> List.to_string
              |> String.split("#")
              |> hd

            "actor model: " <> new_url

          _ -> nil
        end
    end
  end
end
