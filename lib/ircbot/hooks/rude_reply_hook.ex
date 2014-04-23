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
