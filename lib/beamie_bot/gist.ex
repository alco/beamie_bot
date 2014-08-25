defmodule BeamieBot.GistAPI do
  def gist_text({expr, output}) do
    output = "# #{escape_newlines(expr)}\n" <> output
    # replace \# with # in the json
    inspected = Regex.replace(~r/(?<=[^\\])\\#/, inspect(output), "#")
    json = """
    {
      "description": "",
      "public": true,
      "files": {
        "output": {
          "content": #{inspected}
        }
      }
    }
    """
    result = :httpc.request(:post, {'https://api.github.com/gists', [{'User-Agent', 'beamie bot'}], 'application/json', json}, [], [sync: true])
    case result do
      {:error, _reason} ->
        IO.inspect _reason
        "*failed to gist the output*"
      {:ok, {status, _headers, data} } ->
        IO.inspect status
        case status do
          {_, 201, _} ->
            json = List.to_string(data)
            case Regex.run(~r/"html_url":\s*"([^"]+)",/, json) do
              [_, url] -> url
              _        -> "*failed to gist the output*"
            end

          _ ->
            "*failed to gist the output*"
        end
    end
  end


  defp escape_newlines("") do
    ""
  end

  defp escape_newlines(<<?\n::utf8>> <> rest) do
    <<?\\, ?n>> <> escape_newlines(rest)
  end

  defp escape_newlines(<<?\r::utf8>> <> rest) do
    <<?\\, ?r>> <> escape_newlines(rest)
  end

  defp escape_newlines(<<?\t::utf8>> <> rest) do
    <<?\\, ?t>> <> escape_newlines(rest)
  end

  defp escape_newlines(<<c::utf8>> <> rest) do
    <<c::utf8>> <> escape_newlines(rest)
  end
end
