defmodule IRCBot.Connection do
  @nickname "beamie"
  #@channel "exligir"
  @channel "elixir-lang"

  defrecord State, [text_hooks: [], token_hooks: []] do
    def add_hook(id, {:text, f}, state) do
      state.update_text_hooks(fn hooks -> hooks ++ [{id, f}] end)
    end

    def add_hook(id, {:token, f}, state) do
      state.update_token_hooks(fn hooks -> hooks ++ [{id, f}] end)
    end

    def remove_hook(id, state=State[text_hooks: text, token_hooks: token]) do
      state.text_hooks(Keyword.delete(text, id)).token_hooks(Keyword.delete(token, id))
    end
  end

  def start_link() do
    pid = spawn_link(&connect/0)
    Process.register(pid, __MODULE__)
  end

  def add_hook(id, hook) do
    Process.send(__MODULE__, {:internal, {:add_hook, id, hook}})
  end

  def remove_hook(id) do
    Process.send(__MODULE__, {:internal, {:remove_hook, id}})
  end

  defp connect(host \\ 'irc.freenode.net', port \\ 6667) do
    {:ok, sock} = :gen_tcp.connect(host, port, packet: :line, active: true)

    sock
    |> irc_cmd("PASS", "*")
    |> irc_cmd("NICK", @nickname)
    |> irc_cmd("USER", "#{@nickname} 0 * :BEAM")
    |> irc_cmd("JOIN", "\##{@channel}")
    |> message_loop(State.new)
  end

  defp message_loop(sock, state) do
    state = receive do
      {:internal, msg} ->
        case msg do
          {:add_hook, id, hook} ->
            state.add_hook(id, hook)
          {:remove_hook, id} ->
            state.remove_hook(id)
          other ->
            raise RuntimeError[message: "unhandled internal msg #{inspect other}"]
        end

      {:tcp, ^sock, msg} ->
        msg = String.from_char_list!(msg) |> String.strip
        case process_msg(msg) do
          {:msg, msg} ->
            process_hooks(msg, state, sock)
          {:reply, reply} ->
            irc_cmd(sock, "PRIVMSG", "\##{@channel} :#{reply}")
          :pong ->
            irc_cmd(sock, "PONG", @nickname)
          _ -> nil
        end
        state

      other ->
        raise RuntimeError[message: "unhandled msg #{inspect other}"]
    end
    message_loop(sock, state)
  end

  def process_hooks(msg, State[text_hooks: text, token_hooks: token], sock) do
    Enum.each(text, fn {_, f} -> resolve_hook_result(f.(msg), sock) end)

    tokens = tokenize(msg)
    Enum.each(token, fn {_, f} -> resolve_hook_result(f.(tokens), sock) end)
  end

  defp tokenize(msg) do
    String.split(msg, ~r"[[:space:]]")
  end

  defp resolve_hook_result(nil, _sock) do
    nil
  end

  defp resolve_hook_result({:reply, text}, sock) do
    irc_cmd(sock, "PRIVMSG", "\##{@channel} RECEIVER: :#{text}")
  end

  defp resolve_hook_result({:msg, text}, sock) do
    irc_cmd(sock, "PRIVMSG", "\##{@channel} :#{text}")
  end

  defp resolve_hook_result(messages, sock) when is_list(messages) do
    Enum.each(messages, &resolve_hook_result(&1, sock))
  end


  defp irc_cmd(sock, cmd, rest) do
    IO.puts "Executing command #{cmd}"
    :ok = :gen_tcp.send(sock, "#{cmd} #{rest}\r\n")
    sock
  end

  defp process_msg(msg) do
    IO.puts msg

    {_prefix, command, args} = parse_msg(msg)
    case command do
      'PRIVMSG' ->
        [_chan, msg] = args
        case msg do
          "!eval " <> expr ->
            IO.puts "Eval expr #{expr}"
            {:reply, Evaluator.eval(expr)}
          _ -> {:msg, msg}
        end
      'PING' ->
        :pong
      _ -> nil
    end
  end

  #:true_droid!~true_droi@sour-accorder.volia.net PRIVMSG #elixir-lang :beamie: hello
  defp parse_msg(":" <> rest) do
    {prefix, rest} = parse_until(rest, ? )
    {nil, cmd, args} = parse_msg(rest)
    {prefix, cmd, args}
  end

  defp parse_msg(msg) do
    {cmd, argstr} = parse_until(msg, ? )
    {nil, cmd, parse_args(argstr)}
  end


  defp parse_args(str), do: parse_args(str, [], [])

  defp parse_args(" " <> rest, [], acc) do
    parse_args(rest, [], acc)
  end

  defp parse_args(" " <> rest, arg, acc) do
    parse_args(rest, [], [String.from_char_list!(Enum.reverse(arg))|acc])
  end

  defp parse_args(":" <> rest, [], acc) do
    Enum.reverse([rest|acc])
  end

  defp parse_args("", [], acc) do
    Enum.reverse(acc)
  end

  defp parse_args("", arg, acc) do
    Enum.reverse([String.from_char_list!(Enum.reverse(arg))|acc])
  end

  defp parse_args(<<char::utf8, rest::binary>>, arg, acc) do
    parse_args(rest, [char|arg], acc)
  end


  defp parse_until(bin, char) do
    parse_until(bin, char, [])
  end

  defp parse_until(<<char::utf8>> <> rest, char, acc) do
    {Enum.reverse(acc), rest}
  end

  defp parse_until(<<char::utf8>> <> rest, mark, acc) do
    parse_until(rest, mark, [char|acc])
  end
end

defmodule IssueHook do
  def run(text) do
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

defmodule DocHook do
  def run(text) do
    mid_frag = "[A-Z][[:alnum:]_]*"
    mid = "#{mid_frag}(?:\.#{mid_frag})*"
    fid = "[^A-Z](?:[^/[:space:].]|/(?!\\d))*"

    module_re = ~r"(?<= |^)doc (#{mid})(?= |$)"
    fun_re    = ~r"(?<= |^)doc (#{fid})(?:/(\d))?(?= |$)"
    mfa_re    = ~r"(?<= |^)doc (#{mid})\.(#{fid})(?:/(\d))?(?= |$)"

    result = extract_module_doc(module_re, text)
          || extract_local_doc(fun_re, text)
          || extract_mfa_doc(mfa_re, text)
    result && {:msg, result}
  end

  defp extract_module_doc(re, text) do
    modname = case Regex.run(re, text) do
      [_, modname] ->
        mod = Module.concat([modname])
        case (Code.ensure_loaded?(mod) && mod.__info__(:moduledoc)) do
          {_, doc} -> doc && modname
          _        -> nil
        end
      _ -> nil
    end
    modname && make_module_url(modname)
  end

  defp extract_local_doc(re, text) do
    case Regex.run(re, text) do
      [_, fname] ->
        process_module("Kernel", fname, :all)
      [_, fname, arity] ->
        process_module("Kernel", fname, binary_to_integer(arity))
      _ -> nil
    end
  end

  defp extract_mfa_doc(re, text) do
    case Regex.run(re, text) do
      [_, modname, fname] ->
        process_module(modname, fname, :all)
      [_, modname, fname, arity] ->
        process_module(modname, fname, binary_to_integer(arity))
      _ -> nil
    end
  end

  defp process_module(modname, fname, arity) do
    mod = Module.concat([modname])
    fun = try do
      binary_to_existing_atom(fname)
    rescue
      ArgumentError -> nil
    end
    arity = Code.ensure_loaded?(mod) && check_arity_doc(mod, fun, arity)
    arity && make_mfa_url(modname, fname, arity)
  end

  defp check_arity_doc(mod, fun, :all) do
    # Find the first function with name 'fun' that has a docstring
    Keyword.get_values(mod.__info__(:functions), fun)  # get all arities of fun
    |> Stream.map(fn arity -> check_doc(mod, fun, arity) end)
    |> Enum.reject(&(nil == &1))
    |> List.first()
  end

  defp check_arity_doc(mod, fun, arity) do
    check_doc(mod, fun, arity)
  end

  defp check_doc(mod, fun, arity) do
    case List.keyfind(mod.__info__(:docs), {fun, arity}, 0) do
      {_fun, _line, _typ, _args, doc} ->
        doc && arity
      _ -> nil
    end
  end

  defp make_module_url(modname) do
    "http://elixir-lang.org/docs/master/#{modname}.html"
  end

  defp make_mfa_url(modname, fname, arity) do
    "http://elixir-lang.org/docs/master/#{modname}.html\##{fname}/#{arity}"
  end
end

defmodule LinkHook do
  @nickname "beamie"
  @repo_url "https://github.com/elixir-lang/elixir/"

  def run(text) do
    text = String.downcase(text)
    result = case text do
      "wiki"     -> @repo_url <> "wiki"
      "faq"      -> @repo_url <> "FAQ"
      "talks"    -> @repo_url <> "Talks"
      "projects" -> @repo_url <> "Projects"
      "articles" -> @repo_url <> "Articles"
      "books"    -> @repo_url <> "Books"
      "learn"    -> "http://gaslight.co/blog/the-best-resources-for-learning-elixir"
      "ml talk"  -> ml_talk()
      "ml core"  -> ml_core()
      "sips"     -> "http://elixirsips.com"
      _          -> nil
    end
    result && {:msg, result}
  end

  defp ml_talk() do
    "Questions and discussions for users: elixir-lang-talk (http://bit.ly/ex-ml-talk)."
  end

  defp ml_core() do
    "Development, features, announcements: elixir-lang-core (http://bit.ly/ex-ml-core)."
  end
end

defmodule TriviaHook do
  def run(text) do
    tokens = tokenize(text)
    result = if find_at_least(tokens, [{["mix", "project", "application", "app"], 1}, {["shell", "iex", "repl"], 1}]) do
      "To start an interactive shell with your mix project loaded in it, run `iex -S mix`"
    end
    result && {:msg, result}
  end

  def tokenize(text) do
    Regex.split(~r"[[:space:]]|\b", String.downcase(text), trim: true)
  end

  defp find_at_least(tokens, pairs) do
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
end

:inets.start
:ssl.start
IRCBot.Connection.start_link
IRCBot.Connection.add_hook :issue, {:text, &IssueHook.run/1}
IRCBot.Connection.add_hook :doc, {:text, &DocHook.run/1}
IRCBot.Connection.add_hook :link, {:text, &LinkHook.run/1}
IRCBot.Connection.add_hook :trivia, {:text, &TriviaHook.run/1}
