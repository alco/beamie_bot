defmodule HexHook do
  @moduledoc """
  Searches for a package on hex.pm
  """

  def run(_sender, msg) do
    result = case msg do
      "!pkg " <> rest ->
        encode_query(rest) |> search_hex
      _ -> nil
    end
  end

  defp encode_query(query) do
    query |> String.strip |> URI.encode_www_form
  end

  defp search_hex(query) do
    url = "https://hex.pm/api/packages?search=#{query}" |> to_char_list
    result = :httpc.request(:get, {url, [{'User-Agent', 'beamie bot'}]}, [], [sync: true])
    case result do
      {:ok, {_status, _headers, '[]'} } ->
        {:msg, "No results for #{query}"}
      {:ok, {_status, _headers, data} } ->
        Poison.decode(data) |> decoded
      _ ->
        {:msg, "*could not perform search"}
    end
  end

  defp decoded({:ok, results}) do
    results
    |> Enum.take(3)
    |> Enum.map(&format_result/1)
  end
  defp decoded(_), do: {:msg, "*could not perform search"}

  defp format_result(result) do
    description = result["meta"]["description"] |> String.split("\n") |> hd
    {:msg, "*#{result["name"]}* #{description} - https://hex.pm/packages/#{result["name"]}"}
  end
end
