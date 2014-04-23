defmodule IRCBot.Server do
  use GenServer.Behaviour

  defrecord State, hooks: []

  def init(_) do
    {:ok, State.new}
  end

  def add_hook(hook) do
    :gen_server.cast({:add_hook, hook})
  end

  def handle_cast({:add_hook, hook}, state) do
    {:noreply, state.update_hooks(fn hooks -> [hooks] ++ [hook] end)}
  end
end
