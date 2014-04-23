defmodule PingHook do
  @replies [
    "pong", "shpunk", "spank", "pork", "dong",
  ]
  @num_replies Enum.count(@replies)

  def run(sender, text) do
    if String.downcase(text) == "ping" do
      {:reply, sender, Enum.at(@replies, :random.uniform(@num_replies)-1)}
    end
  end
end
