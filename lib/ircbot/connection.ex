defmodule IRCBot.Connection do
  @nickname "beamie"
  #@channel "exligir"
  @channel "elixir-lang"

  require Record

  Record.defrecordp :hookrec, [type: nil, direct: false, exclusive: false, fn: nil]

  alias __MODULE__, as: State
  defstruct hooks: []

  defp state_add_hook(state, id, f, opts) do
    hook = Enum.reduce(opts, hookrec(fn: f), fn
      {:in, type}, rec ->
        hookrec(rec, type: type)
      {:direct, flag}, rec ->
        hookrec(rec, direct: flag)
      {:exclusive, flag}, rec ->
        hookrec(rec, exclusive: flag)
    end)
    Map.update!(state, :hooks, &( &1 ++ [{id, hook}] ))
  end

  defp state_remove_hook(state=%State{hooks: hooks}, id) do
    %{state | hooks: Keyword.delete(hooks, id)}
  end


  def start_link() do
    pid = spawn_link(&connect/0)
    Process.register(pid, __MODULE__)
  end

  def add_hook(id, f, opts \\ []) do
    send(__MODULE__, {:internal, {:add_hook, id, f, opts}})
  end

  def remove_hook(id) do
    send(__MODULE__, {:internal, {:remove_hook, id}})
  end


  @nsec 10
  @ping_sec 5 * 60
  @maxattempts 30

  defp sleep_sec(n), do: :timer.sleep(n * 1000)

  def connect(host \\ 'irc.freenode.net', port \\ 6667) do
    case :gen_tcp.connect(host, port, packet: :line, active: true) do
      {:ok, sock} ->
        Process.delete(:connect_attempts)
        handshake(sock)

      other ->
        IO.puts "Failed to connect: #{inspect other}"
        nattempts = Process.get(:connect_attempts, 0)
        if nattempts >= @maxattempts do
          IO.puts "FAILED TO CONNECT #{@maxattempts} TIMES IN A ROW. SHUTTING DOWN"
          :erlang.halt()
        else
          Process.put(:connect_attempts, nattempts+1)
          IO.puts "RETRYING IN #{@nsec} SECONDS"
          sleep_sec(@nsec)
          connect(host, port)
        end
    end
  end

  defp handshake(sock) do
    :random.seed(:erlang.now())

    sock
    |> irc_cmd("PASS", "*")
    |> irc_cmd("NICK", @nickname)
    |> irc_cmd("USER", "#{@nickname} 0 * :BEAM")
    |> irc_cmd("PRIVMSG", "NickServ :identify #{System.get_env("BEAMIE_BOT_PWD")}")
    |> irc_cmd("JOIN", "\##{@channel}")
    |> message_loop(%State{})
  end

  def message_loop(sock, state) do
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
        msg = List.to_string(msg) |> String.strip
        case process_msg(msg) do
          {:msg, sender, msg} ->
            try do
              process_hooks({sender, msg}, state, sock)
            rescue
              x -> IO.inspect x
            end
          {:reply, reply} ->
            irc_cmd(sock, "PRIVMSG", "\##{@channel} :#{reply}")
          :pong ->
            irc_cmd(sock, "PONG", @nickname)
          _ -> nil
        end
        state

      {:tcp_closed, ^sock} ->
        IO.puts "SOCKET CLOSE; RETRYING CONNECT IN #{@nsec} SECONDS"
        nil

      {:tcp_error, ^sock, reason} ->
        IO.puts "SOCKET ERROR: #{inspect reason}\nRETRYING CONNECT IN #{@nsec} SECONDS"
        nil

      other ->
        raise RuntimeError[message: "unhandled msg #{inspect other}"]

      after @ping_sec * 1000 ->
        IO.puts "No ping message in #{@ping_sec} seconds. Retrying connect."
        :gen_tcp.close(sock)
        nil
    end
    if state do
      __MODULE__.message_loop(sock, state)
    else
      sleep_sec(@nsec)
      __MODULE__.connect()
    end
  end

  def process_hooks({sender, msg}, %State{hooks: hooks}, sock) do
    receiver = get_message_receiver(msg)
    #IO.puts "receiver: '#{receiver}', sender: '#{sender}'"

    tokens = tokenize(msg)
    Enum.reduce(hooks, 0, fn
      {_, hookrec(type: type, direct: direct, exclusive: ex, fn: f)}, successes ->
	#IO.puts "testing hook: #{inspect f}"
        if ((not direct) || (receiver == @nickname)) && ((not ex) || (successes == 0)) do
          arg = case type do
            :text  -> if direct do strip_msg_receiver(msg, receiver) else msg end
            :token -> tokens
          end

	  #IO.puts "applying hook: #{inspect f}"
          if resolve_hook_result(f.(sender, arg), sock) do
            successes+1
          else
            successes
          end
        else
	  #IO.puts "skipping hook: #{inspect f}"
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

  defp resolve_hook_result({:notice, text}, sock) do
    irc_cmd(sock, "NOTICE", "\##{@channel} :#{text}")
  end

  defp resolve_hook_result(messages, sock) when is_list(messages) do
    Enum.reduce(messages, nil, fn msg, status ->
      new_status = resolve_hook_result(msg, sock)
      status || new_status
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
      case Regex.run(~r"^([^! ]+)(?:$|!)", List.to_string(prefix)) do
        [_, sender] -> sender
        other -> IO.puts "bad sender: #{inspect prefix} #{inspect other}"; nil
      end
    end

    case command do
      'PRIVMSG' ->
        [chan, msg] = args
        if chan == @nickname do
          # ignore private messages
          nil
        else
          {:msg, sender, msg}
        end
      #'332' ->
        #{:reply, "Greetings, apprentices"}
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
    parse_args(rest, [], [List.to_string(Enum.reverse(arg))|acc])
  end

  defp parse_args(":" <> rest, [], acc) do
    Enum.reverse([rest|acc])
  end

  defp parse_args("", [], acc) do
    Enum.reverse(acc)
  end

  defp parse_args("", arg, acc) do
    Enum.reverse([List.to_string(Enum.reverse(arg))|acc])
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
