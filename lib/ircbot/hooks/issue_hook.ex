defmodule IssueHook do
  def run(_sender, text) do
    IO.puts "Testing text for issues: '#{text}'"
    Regex.scan(~r"(?: |^)#(\d+)(?:(?=[[:space:]])|$)|issue[[:space:]]+#?(\d+)(?:(?=[[:space:]])|$)", text)
    |> Enum.map(fn x ->
         [_, num] = Enum.reject(x, &match?("", &1))
         num
       end)
    #|> pfilter(&issue_valid?/1)
    |> Enum.map(fn x -> {:msg, "https://github.com/elixir-lang/elixir/issues/#{x}"} end)
  end

  defp issue_valid?(num) do
    url_valid?('https://api.github.com/repos/elixir-lang/elixir/issues/#{num}')
  end

  defp url_valid?(url) do
    case :httpc.request(:head, {url, [{'User-Agent', 'httpc'}]}, [], []) do
      {:ok, {{_, status, _response}, _headers, _}} ->
        status != 404
      _ -> nil
    end
  end


  defp pfilter(coll, f) do
    #IO.puts "Filtering #{inspect coll}"
    parent = self()
    Enum.map(coll, fn elem ->
      spawn(fn -> Process.send(parent, {self(), elem, f.(elem)}) end)
    end) |> collect_replies
  end

  defp collect_replies(pids) do
    collect_replies(pids, [])
  end

  defp collect_replies([], acc) do
    Enum.reverse(acc)
  end

  defp collect_replies(pids, acc) do
    receive do
      {pid, elem, reply} ->
        #IO.puts "Got reply: #{inspect elem} #{inspect reply}"
        acc = if reply do
          [elem|acc]
        else
          acc
        end
        collect_replies(List.delete(pids, pid), acc)
    after 1000 ->
      #IO.puts "Timout"
      []
    end
  end
end
