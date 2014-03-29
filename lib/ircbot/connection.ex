defmodule IRCBot.Connection do
  @nickname "beamie"
  @channel "exligir"
  #@channel "elixir-lang"

  defrecordp :hookrec, [type: nil, direct: false, fn: nil]
  defrecord State, hooks: []

  defp state_add_hook(state, id, f, opts) do
    hook = Enum.reduce(opts, hookrec(fn: f), fn
      {:in, type}, rec ->
        hookrec(rec, type: type)
      {:direct, flag}, rec ->
        hookrec(rec, direct: flag)
    end)
    state.update_hooks(&( &1 ++ [{id, hook}] ))
  end

  defp state_remove_hook(state=State[hooks: hooks], id) do
    state.hooks(Keyword.delete(hooks, id))
  end


  def start_link() do
    pid = spawn_link(&connect/0)
    Process.register(pid, __MODULE__)
  end

  def add_hook(id, f, opts \\ []) do
    Process.send(__MODULE__, {:internal, {:add_hook, id, f, opts}})
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
          {:add_hook, id, f, opts} ->
            state_add_hook(state, id, f, opts)
          {:remove_hook, id} ->
            state_remove_hook(state, id)
          other ->
            raise RuntimeError[message: "unhandled internal msg #{inspect other}"]
        end

      {:tcp, ^sock, msg} ->
        msg = String.from_char_list!(msg) |> String.strip
        case process_msg(msg) do
          {:msg, sender, msg} ->
            process_hooks({sender, msg}, state, sock)
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

  def process_hooks({sender, msg}, State[hooks: hooks], sock) do
    receiver = get_message_receiver(msg)
    IO.puts "receiver: '#{receiver}', sender: '#{sender}'"

    tokens = tokenize(msg)
    Enum.each(hooks, fn
      {_, hookrec(type: type, direct: direct, fn: f)} ->
        if (not direct) || (receiver == @nickname) do
          arg = case type do
            :text  -> if direct do strip_msg_receiver(msg, receiver) else msg end
            :token -> tokens
          end
          resolve_hook_result(f.(sender, arg), sock)
        end
    end)
  end

  defp get_message_receiver(msg) do
    case Regex.run(~r"^([-_^[:alnum:]]+)(?::)", msg) do
      [_, name] -> name
      _ -> nil
    end
  end

  defp strip_msg_receiver(msg, receiver) do
    msg
    |> String.slice(byte_size(receiver), byte_size(msg))
    |> String.lstrip(?:)
    |> String.strip()
  end

  defp tokenize(msg) do
    String.split(msg, ~r"[[:space:]]")
  end

  defp resolve_hook_result(nil, _sock) do
    nil
  end

  defp resolve_hook_result({:reply, text}, sock) do
    irc_cmd(sock, "PRIVMSG", "\##{@channel} #{@nickname}: :#{text}")
  end

  defp resolve_hook_result({:reply, to, text}, sock) do
    irc_cmd(sock, "PRIVMSG", "\##{@channel} :#{to}: #{text}")
  end

  defp resolve_hook_result({:msg, text}, sock) do
    irc_cmd(sock, "PRIVMSG", "\##{@channel} :#{text}")
  end

  defp resolve_hook_result(messages, sock) when is_list(messages) do
    Enum.each(messages, &resolve_hook_result(&1, sock))
  end


  defp irc_cmd(sock, cmd, rest) do
    IO.puts "Executing command #{cmd} with args #{inspect rest}"
    :ok = :gen_tcp.send(sock, "#{cmd} #{rest}\r\n")
    sock
  end

  defp process_msg(msg) do
    IO.puts msg

    {prefix, command, args} = parse_msg(msg)

    sender = if prefix do
      case Regex.run(~r"^([^! ]+)(?:$|!)", String.from_char_list!(prefix)) do
        [_, sender] -> sender
        other -> IO.puts "bad sender: #{inspect prefix} #{inspect other}"; nil
      end
    end

    case command do
      'PRIVMSG' ->
        [_chan, msg] = args
        case msg do
          "!eval " <> expr ->
            IO.puts "Eval expr #{expr}"
            {:reply, Evaluator.eval(expr)}
          _ -> {:msg, sender, msg}
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

defmodule DocHook do
  def run(_sender, text) do
    mid_frag = "[A-Z][[:alnum:]_]*"
    mid = "#{mid_frag}(?:\.#{mid_frag})*"
    fid = "[^A-Z](?:[^/[:space:].]|/(?!\\d))*"

    module_re = ~r"(?<= |^)doc (#{mid})(?= |$)"
    fun_re    = ~r"(?<= |^)doc (#{fid})(?:/(\d))?(?= |$)"
    mfa_re    = ~r"(?<= |^)doc (#{mid})\.(#{fid})(?:/(\d))?(?= |$)"

    result = extract_module_doc(module_re, text)
          || extract_local_doc(fun_re, text)
          || extract_mfa_doc(mfa_re, text)
    result && Enum.map(result, fn text -> {:msg, text} end)
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
    modname && [make_module_url(modname)]
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
    arities = Code.ensure_loaded?(mod) && check_arity_doc(mod, fun, arity)
    arities && Enum.map(arities, fn arity -> make_mfa_url(modname, fname, arity) end)
  end

  defp check_arity_doc(mod, fun, :all) do
    Keyword.get_values(mod.__info__(:functions), fun)  # get all arities of fun
    |> Stream.map(fn arity -> check_doc(mod, fun, arity) end)
    |> Enum.reject(&(nil == &1))
  end

  defp check_arity_doc(mod, fun, arity) do
    arity = check_doc(mod, fun, arity)
    arity && [arity]
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

defmodule LinkHook do
  @wiki_url "https://github.com/elixir-lang/elixir/wiki/"

  def run(_sender, text) do
    result = case String.downcase(text) do
      "wiki"     -> @wiki_url
      "articles" -> @wiki_url <> "Articles"
      "projects" -> @wiki_url <> "Projects"
      "talks"    -> @wiki_url <> "Talks"
      "books"    -> @wiki_url <> "Books"
      "faq"      -> @wiki_url <> "FAQ"
      "learn"    -> "Blog post covering many of the up-to-date learning resources for Elixir: http://gaslight.co/blog/the-best-resources-for-learning-elixir"
      "ml-talk"  -> ml_talk()
      "ml-core"  -> ml_core()
      "sips"     -> "Collection of screencasts covering a wide range of topics: http://elixirsips.com"
      _          -> nil
    end
    result && {:msg, result}
  end

  defp ml_talk() do
    "Mailing list for questions and discussions about Elixir's usage: \x{02}elixir-lang-talk\x{0f} http://bit.ly/ex-ml-talk"
  end

  defp ml_core() do
    "Mailing list for discussing Elixir development, features, announcements: \x{02}elixir-lang-core\x{0f} http://bit.ly/ex-ml-core"
  end
end

defmodule TriviaHook do
  def run(_sender, text) do
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

defmodule PingHook do
  def run(sender, text) do
    IO.inspect text
    if String.downcase(text) == "ping" do
      {:reply, sender, "pong"}
    end
  end
end

:inets.start
:ssl.start
IRCBot.Connection.start_link
IRCBot.Connection.add_hook :issue, &IssueHook.run/2, in: :text
IRCBot.Connection.add_hook :doc, &DocHook.run/2, in: :text
IRCBot.Connection.add_hook :link, &LinkHook.run/2, in: :text, direct: true
IRCBot.Connection.add_hook :linkscan, &LinkScanHook.run/2, in: :text
IRCBot.Connection.add_hook :trivia, &TriviaHook.run/2, in: :text
IRCBot.Connection.add_hook :ping, &PingHook.run/2, [in: :text, direct: true]
