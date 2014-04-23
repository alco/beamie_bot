defmodule RudeReplyHook do
  @erlang_replies [
    "ask nox about it", "erlang? never heard of it", "erlang? what erlang?",
    "erlang? did you mean prolog?", "my lang is not yerlang",
  ]
  @num_replies Enum.count(@erlang_replies)

  def run(sender, text) do
    downtext = String.downcase(text)
    if String.contains?(downtext, "?") do
      cond do
        String.contains?(downtext, "homoiconic") ->
          {:reply, sender, "ask nox about it"}

        String.contains?(downtext, "elixir") ->
          {:reply, sender, "Elixir is the best language there is"}

        String.contains?(downtext, ["homoiconic", "erlang"]) ->
          if sender == "nox" do
            {:reply, sender, "haha, funny"}
          else
            {:reply, sender, Enum.at(@erlang_replies, :random.uniform(@num_replies)-1)}
          end

        true ->
          {:reply, sender, "I don't know. Perhaps you should google it"}
      end
    else
      {:reply, sender, "I don't like you either"}
    end
  end
end
