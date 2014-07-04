defmodule RudeReplyHook do
  @erlang_replies [
    "ask nox about it", "erlang? never heard of it", "erlang? what erlang?",
    "erlang? did you mean prolog?",
    "Erlang was actually heavily inspired by Java -> http://www.infoq.com/news/2011/04/erlang-copied-jvm-and-scala",
  ]
  @num_replies Enum.count(@erlang_replies)

  @question_replies [
    "I don't know. Perhaps you should google it",
    "The answer lies within you",
    "Persistence, student, and you will find the answer",
    "I am not certain at this moment",
    "Let me think about it...",
    "I am sure you realize the answer is obvious",
  ]
  @num_q_replies Enum.count(@question_replies)

  @norm_replies [
    "Patience, student",
    "Let us not discuss this in public",
    "Show restraint, student, and people will look up to you",
    "There is no cow level",
    "The milkman is dead",
    "All your base are belong to me",
    "Seriously ?",
    "I hear you",
    "Tell me more",
    "Ai caramba !",
    "no hablo inglés",
    "そうですか...",
  ]
  @num_n_replies Enum.count(@norm_replies)

  def run("nox", text) do
    EvalHook.run "nox", "erl~ "<>text
  end

  def run(sender, text) do
    downtext = String.downcase(text)
    if String.contains?(downtext, "?") do
      cond do
        String.contains?(downtext, "homoiconic") ->
          {:reply, sender, "ask nox about it"}

        String.contains?(downtext, "elixir") ->
          {:reply, sender, "Elixir is the best language there is"}

        String.contains?(downtext, "deprecate") ->
          {:reply, sender, "Deprecate all the things! The brokener the better"}

        String.contains?(downtext, ["erlang"]) ->
          {:reply, sender, random_from(@erlang_replies, @num_replies)}

        String.contains?(downtext, ["homoiconic", "erlang"]) ->
          if sender == "nox" do
            {:reply, sender, "haha, funny"}
          else
            {:reply, sender, random_from(@erlang_replies, @num_replies)}
          end

        true ->
          {:reply, sender, random_from(@question_replies, @num_q_replies)}
      end
    else
      {:reply, sender, random_from(@norm_replies, @num_n_replies)}
    end
  end

  defp random_from(list, count \\ 0) do
    if count == 0, do: count = length(list)
    Enum.at(list, :random.uniform(count)-1)
  end
end
