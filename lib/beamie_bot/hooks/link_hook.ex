defmodule LinkHook do
  @moduledoc """
  Convert predefined references to links to corresponding online resources.
  """

  @wiki_url "https://github.com/elixir-lang/elixir/wiki/"

  def run(text, _sender, _chan) do
    result = case String.downcase(text) do
      "wiki"     -> @wiki_url
      "articles" -> @wiki_url <> "Articles"
      "projects" -> @wiki_url <> "Projects"
      "talks"    -> @wiki_url <> "Talks"
      "books"    -> @wiki_url <> "Books"
      "meetups"  -> @wiki_url <> "Meetups"
      "faq"      -> @wiki_url <> "FAQ"
      "learn"    -> "Blog post covering many of the up-to-date learning resources for Elixir: http://gaslight.co/blog/the-best-resources-for-learning-elixir"
      "ml-talk"  -> ml_talk()
      "ml-core"  -> ml_core()
      "twitter"  -> "Twitter search with elixir-related hashtags https://twitter.com/search?f=realtime&q=%23elixirlang%20OR%20%23myelixirstatus%20OR%20%40elixirlang&src=typd"
      "hex"      -> "hex is a package manager for Elixir. Browse available packages at https://hex.pm"
      "sips"     -> "Collection of screencasts covering a wide range of topics: http://elixirsips.com"
      #"r17osx"   -> "install R17 on OS X: `brew update && brew install --no-docs --devel erlang` or download from https://www.erlang-solutions.com/downloads/download-erlang-otp"

      #"elixirconf" -> "ElixirConf is an upcoming conference (July 25-26, 2014 Austin, TX). See http://elixirconf.com/"
      _          -> nil
    end
    result && {:msg, result}
  end

  defp ml_talk() do
    "Mailing list for questions and discussions about Elixir's usage: \x{02}elixir-lang-talk\x{0f} http://bit.ly/ex-ml-talk"
  end

  defp ml_core() do
    "Mailing list for discussing Elixir development, features, announcements: \x{02}elixir-lang-core\x{0f} http://bit.ly/ex-ml-core"
  end
end
