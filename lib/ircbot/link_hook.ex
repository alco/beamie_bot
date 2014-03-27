defmodule IRCBot.Hook.Link do
  @nickname "beamie"

  alias IRCBot.Message, as: M
  use IRCBot.Hook

  def msg_receive(:after, msg=M[receiver: @nickname, text: text]) do
    tokens = M.tokenize(text)
    cond do
      M.contains_exact(tokens, ["learn"]) ->
        "http://gaslight.co/blog/the-best-resources-for-learning-elixir"

      M.contains_exact(tokens, ["wiki"]) ->
        "https://github.com/elixir-lang/elixir/wiki"

      M.contains_exact(tokens, ["faq"]) ->
        "https://github.com/elixir-lang/elixir/wiki/FAQ"

      M.contains_exact(tokens, ["talks"]) ->
        "https://github.com/elixir-lang/elixir/wiki/Talks"

      M.contains_exact(tokens, ["books"]) ->
        "https://github.com/elixir-lang/elixir/wiki/Books"

      M.contains_regex(tokens, [%r"#(\d+)"]) ->
        "https://github.com/elixir-lang/elixir/issues/#{issue_no}"

      M.contains_sequence(tokens, ["doc", x]) ->
        "http://elixir-lang.org/docs/master/#{x}.html"

      M.contains(tokens, ["archives"]) ->
        "https://groups.google.com/forum/#!searchin/elixir-lang-core/#{search_term}"
        "https://groups.google.com/forum/#!searchin/elixir-lang-talk/#{search_term}"

      M.contains(tokens, ["ml talk"]) -> ml_talk()

      M.contains(tokens, ["ml core"]) -> ml_core()

      M.contains(tokens, ["ml"]) -> ml_talk() <> " " <> ml_core()
    end
  end

  defp ml_talk() do
    "Questions and discussions for users: elixir-lang-talk (http://bit.ly/ex-ml-talk)."
  end

  defp ml_core() do
    "Development, features, announcements: elixir-lang-core (http://bit.ly/ex-ml-core)."
  end

  defp contains
end
