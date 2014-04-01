defmodule Evaluator do
  def eval(expr, version \\ "0.12.5") do
    result = :httpc.request(:post, {'http://localhost:8001/eval/elixir/#{version}', [], '', expr}, [], [sync: true])
    case result do
      {:error, _reason} ->
        IO.inspect _reason
        "*internal service error*"
      {:ok, {status, _headers, data} } ->
        IO.inspect status
        reply = data |> String.from_char_list! |> String.strip
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

defmodule IRCBot.Connection do
  @nickname "beamie"
  @channel "exligir"
  #@channel "elixir-lang"

  defrecordp :hookrec, [type: nil, direct: false, exclusive: false, fn: nil]
  defrecord State, hooks: []

  defp state_add_hook(state, id, f, opts) do
    hook = Enum.reduce(opts, hookrec(fn: f), fn
      {:in, type}, rec ->
        hookrec(rec, type: type)
      {:direct, flag}, rec ->
        hookrec(rec, direct: flag)
      {:exclusive, flag}, rec ->
        hookrec(rec, exclusive: flag)
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
    Enum.reduce(hooks, 0, fn
      {_, hookrec(type: type, direct: direct, exclusive: ex, fn: f)}, successes ->
        if ((not direct) || (receiver == @nickname)) && ((not ex) || (successes == 0)) do
          arg = case type do
            :text  -> if direct do strip_msg_receiver(msg, receiver) else msg end
            :token -> tokens
          end

          if resolve_hook_result(f.(sender, arg), sock) do
            successes+1
          else
            successes
          end
        else
          successes
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
    Enum.reduce(messages, nil, fn msg, status ->
      status || resolve_hook_result(msg, sock)
    end)
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
      "r17osx"   -> "install R17 on OS X: `brew update && brew install --no-docs --devel erlang` or download from https://www.erlang-solutions.com/downloads/download-erlang-otp"
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
    result = cond do
      find_at_least(tokens, [{["mix", "project", "application", "app"], 1}, {["shell", "iex", "repl"], 1}, {["?"], 1}]) ->
        "To start an interactive shell with your mix project loaded in it, run `iex -S mix`"

      find_at_least(tokens, [{["records"], 1}, {["remove", "removed"], 1}]) or find_at_least(tokens, [{["records"], 1}, {["replace", "replaced"], 1}, {["maps", "structs"], 1}]) ->
        "In Elixir v0.13 maps and structs are going to replace records. See this proposal https://gist.github.com/josevalim/b30c881df36801611d13. Privare records remain unchanged."

      true -> nil
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

defmodule RudeReplyHook do
  def run(sender, text) do
    downtext = String.downcase(text)
    if String.ends_with?(downtext, "?") do
      if String.contains?(downtext, ["homoiconic", "erlang"]) do
        if sender == "nox" do
          {:reply, sender, "haha, funny"}
        else
          {:reply, sender, "ask nox about it"}
        end
      else
        {:reply, sender, "I don't know. Perhaps you should google it"}
      end
    else
      {:reply, sender, "I don't like you either"}
    end
  end
end

defmodule LikeWhatHook do
  @phrases [
    "literally",
    "a dog's bullocks",
    "a barmy",
    "bees knees",
    "a doddle",
    "a dog's dinner",
    "Her Majesty's pleasure",
    "John Thomas",
    "a piece of cake",
    "rumpy pumpy",
    "spending a penny",
    "sweet fanny adams",
    "taking the mickey",
    "taking the biscuit",
    "you",
    "me",
    "my uncle Bob",
    "it's been written in Erlang",
    "a dash of lemon"
  ]
  @phrases_count length(@phrases)

  def run(sender, text) do
    if Regex.match?(~r"^like what\??$"i, text) do
      index = :random.uniform(@phrases_count)-1
      {:reply, sender, "like " <> Enum.at(@phrases, index)}
    end
  end
end

defmodule EvalHook do
  def run(_sender, msg) do
    case msg do
      "eval~ " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr))}

      "eval~13 " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), "0.13")}

      _ -> nil
    end
  end
end


defmodule Bot do
  def run do
    :inets.start
    :ssl.start
    :random.seed(:erlang.now())
    IRCBot.Connection.start_link
    IRCBot.Connection.add_hook :issue, &IssueHook.run/2, in: :text
    IRCBot.Connection.add_hook :doc, &DocHook.run/2, in: :text
    IRCBot.Connection.add_hook :link, &LinkHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :linkscan, &LinkScanHook.run/2, in: :text
    IRCBot.Connection.add_hook :trivia, &TriviaHook.run/2, in: :text
    IRCBot.Connection.add_hook :ping, &PingHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :rudereply, &RudeReplyHook.run/2, in: :text, direct: true, exclusive: true
    IRCBot.Connection.add_hook :likewhat, &LikeWhatHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :eval, &EvalHook.run/2, in: :text
  end
end
