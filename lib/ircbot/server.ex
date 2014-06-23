defmodule IRCBot.Server do
  use GenServer

  def init(_) do
    {:ok, []}
  end

  def add_hook(hook) do
    :gen_server.cast({:add_hook, hook})
  end

  def handle_cast({:add_hook, hook}, hooks) do
    {:noreply, hooks ++ [hook]}
  end
end
