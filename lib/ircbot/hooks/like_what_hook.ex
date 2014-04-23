defmodule LikeWhatHook do
  @phrases [
    "literally",
    "a dog's bullocks",
    "a barmy",
    "bees knees",
    "a doddle",
    "a dog's dinner",
    "Her Majesty's pleasure",
    "John Thomas",
    "a piece of cake",
    "rumpy pumpy",
    "spending a penny",
    "sweet fanny adams",
    "taking the mickey",
    "taking the biscuit",
    "you",
    "me",
    "my uncle Bob",
    "it's been written in Erlang",
    "a dash of lemon"
  ]
  @phrases_count length(@phrases)

  def run(sender, text) do
    if Regex.match?(~r"^like what\??$"i, text) do
      index = :random.uniform(@phrases_count)-1
      {:reply, sender, "like " <> Enum.at(@phrases, index)}
    end
  end
end
