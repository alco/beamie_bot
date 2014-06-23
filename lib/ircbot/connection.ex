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

  defp connect(host \\ 'irc.freenode.net', port \\ 6667) do
    {:ok, sock} = :gen_tcp.connect(host, port, packet: :line, active: true)

    :random.seed(:erlang.now())

    sock
    |> irc_cmd("PASS", "*")
    |> irc_cmd("NICK", @nickname)
    |> irc_cmd("USER", "#{@nickname} 0 * :BEAM")
    |> irc_cmd("JOIN", "\##{@channel}")
    |> message_loop(%State{})
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

      other ->
        raise RuntimeError[message: "unhandled msg #{inspect other}"]
    end
    message_loop(sock, state)
  end

  def process_hooks({sender, msg}, %State{hooks: hooks}, sock) do
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
        [_chan, msg] = args
        {:msg, sender, msg}
      '332' ->
        {:reply, "Greetings, apprentices"}
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
