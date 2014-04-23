defmodule PingHook do
  def run(sender, text) do
    if String.downcase(text) == "ping" do
      {:reply, sender, "pong"}
    end
  end
end
