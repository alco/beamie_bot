defmodule PingHook do
  @moduledoc """
  Reply with a randomly chosen response to ping messages.
  """

  @replies [
    "pong", "zap", "spank", "pow", "bang", "ka-pow", "woosh", "smack", "pink",
  ]
  @num_replies Enum.count(@replies)

  @nox_replies ["<(｀^´)>", "<3"]

  def run(text, sender, _chan) do
    case String.downcase(text) do
      "ping" ->
        if sender == "nox" do
          {:reply, sender, Enum.at(@nox_replies, :random.uniform(2)-1)}
        else
          {:reply, sender, Enum.at(@replies, :random.uniform(@num_replies)-1)}
        end
      _ -> nil
    end
  end
end
