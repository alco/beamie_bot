defmodule PingHook do
  @replies [
    "pong", "shpunk", "spank", "pork", "dong",
  ]
  @num_replies Enum.count(@replies)

  def run(sender, text) do
    case String.downcase(text) do
      "ping" ->
        if sender == "nox" do
          {:reply, sender, "<3"}
        else
          {:reply, sender, Enum.at(@replies, :random.uniform(@num_replies)-1)}
        end
      "ping nox" ->
        {:reply, "nox", "<3"}

      _ -> nil
    end
  end
end
