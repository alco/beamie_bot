defmodule LinkScanHook do
  @moduledoc """
  Scan messages for occurrences of link patterns followed by a tilde and
  convert them links.
  """

  def run(text, sender, chan) do
    mid_frag = "[A-Z][[:alnum:]_]*"
    mid = "#{mid_frag}(?:\.#{mid_frag})*"
    fid = "[^A-Z](?:[^/[:space:].]|/(?!\\d))*"

    module_re = ~r"(?<=&|^| )#{mid}(?=~$)"
    fun_re    = ~r"(?<=&|^| )#{fid}(?:/\d)?(?=~$)"
    mfa_re    = ~r"(?<=&|^| )#{mid}\.#{fid}(?:/\d)?(?=~$)"
    twitter_re = ~r"(?<=\s|^)@([a-zA-Z_]+)"

    mapf(Regex.scan(~r"\b([-_[:alnum:]]+)~", text), fn [_, word] ->
      LinkHook.run(word, sender, chan)
    end)
    ++
    flatmapf(Regex.scan(module_re, text), fn [thing] ->
      DocHook.run("doc " <> thing, sender, chan)
    end)
    ++
    flatmapf(Regex.scan(fun_re, text), fn [thing] ->
      DocHook.run("doc " <> thing, sender, chan)
    end)
    ++
    flatmapf(Regex.scan(mfa_re, text), fn [thing] ->
      DocHook.run("doc " <> thing, sender, chan)
    end)
    ++
    mapf(Regex.scan(twitter_re, text), fn [_, name] ->
      if String.contains?(String.downcase(text), "twitter") do
        {:msg, "https://twitter.com/#{name}"}
      end
    end)
  end

  defp mapf(c, f) do
    Enum.map(c, f) |> Enum.reject(&(nil == &1))
  end

  defp flatmapf(c, f) do
    Enum.flat_map(c, f) |> Enum.reject(&(nil == &1))
  end
end
