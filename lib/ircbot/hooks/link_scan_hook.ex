defmodule LinkScanHook do
  def run(sender, text) do
    mid_frag = "[A-Z][[:alnum:]_]*"
    mid = "#{mid_frag}(?:\.#{mid_frag})*"
    fid = "[^A-Z](?:[^/[:space:].]|/(?!\\d))*"

    module_re = ~r"(?<=&|^| )#{mid}(?=~)"
    fun_re    = ~r"(?<=&|^| )#{fid}(?:/(\d))?(?=~)"
    mfa_re    = ~r"(?<=&|^| )#{mid}\.#{fid}(?:/\d)?(?=~)"

    (
    Regex.scan(~r"\b([-_[:alnum:]]+)~", text)
    |> mapf(fn [_, word] ->
         LinkHook.run(sender, word)
       end)
    ) ++ (
    Regex.scan(module_re, text)
    |> flatmapf(fn [thing] ->
         DocHook.run(sender, "doc " <> thing)
       end)
    ) ++ (
    Regex.scan(fun_re, text)
    |> flatmapf(fn [thing] ->
         DocHook.run(sender, "doc " <> thing)
       end)
    ) ++ (
    Regex.scan(mfa_re, text)
    |> flatmapf(fn [thing] ->
         DocHook.run(sender, "doc " <> thing)
       end)
    )
  end

  defp mapf(c, f) do
    Enum.map(c, f) |> Enum.reject(&(nil == &1))
  end

  defp flatmapf(c, f) do
    Enum.flat_map(c, f) |> Enum.reject(&(nil == &1))
  end
end
