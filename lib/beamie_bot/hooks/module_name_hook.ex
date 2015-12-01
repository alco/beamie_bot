defmodule ModuleNameHook do
  @moduledoc """
  Generate silly module names on request.

  ## Example

      user       | beamie_bot: gen name
      beamie_bot | PeachyPlugin

  """

  @adjectives [
    general: [
        "saucy", "raring", "spicy", "smelly", "obnoxious",
        "salty", "sticky", "gory", "partly", "stylish",
        "shiny", "fervent", "obtuse", "obtrusive",
        "sweet", "french", "english", "chinese", "nerdy",
        "cute", "tiny", "crappy", "busy", "cheesy", "sullen",
        "hilarious", "iconic", "tragic",
        "magical", "spiteful", "rugged", "wicked", "swedish",
        "musical", "peppered", "tidy", "borked",
        "boastful", "posh", "peachy", "loud",
        "silent", "practical", "pointless", "impractical",
    ],
    technical: [
        "pure", "homoiconic", "visual", "vocal", "verbal",
        "unary", "binary", "decimal", "digital", "analogue",
        "compressed", "encrypted", "patented",
        "processed", "preprocessed", "infinite", "lossy",
        "lossless", "progressive", "futuristic",
        "laggy", "speedy", "latent",
        "atomic", "subatomic", "persistent", "consistent",
        "immutable", "mutable", "virtual", "static",
        "numerical", "typed", "functional", "imperative",
        "distributed", "scalable", "syntactic", "semantical",
        "performant", "public", "private",
        "comprehensive", "extensible",
    ],
  ]
  @adjectives_length [general: length(@adjectives[:general]),
                      technical: length(@adjectives[:technical])]

  @nouns [
    general: [
        "fish", "sheep", "bullocks", "noise",
        "broker", "poker", "stoker", "cookie", "dough",
        "cat", "dog", "cucumber", "potato", "bean",
        "bug", "cobra", "camel", "frog", "boxers", "ship",
        "fedora", "fez", "tea", "coffee", "mirror",
        "goul", "zombie", "food", "pickle", "knob",

    ],
    technical: [
        "transformer", "transpiler", "parser", "generator", "converter",
        "projector", "switch", "box", "port",
        "decoder", "encoder", "glitch", "request", "handler",
        "server", "client", "module", "interface", "router",
        "clock", "app", "protocol", "socket", "display", "renderer",
        "pipe", "file", "system", "paradigm", "proxy", "logger",
        "task", "driver",  "bin",
        "agent", "transactor", "store", "interpreter",
        "jit", "translator", "compiler", "lambda",
        "terminal", "bot", "engine",
        "button", "device", "plugin", "config",
    ],
  ]
  @nouns_length [general: length(@nouns[:general]),
                 technical: length(@nouns[:technical])]

  @keys [:general, :technical]


  def run(msg, _sender, _chan) do
    tokens = TriviaHook.tokenize(msg)
    if TriviaHook.find_at_least(tokens, [{["module", "gen", "generate"], 1}, {["name"], 1}]) do
      index = :random.uniform(2)-1
      adj_key = Enum.at(@keys, index)
      noun_key = Enum.at(@keys, 1-index)

      adjectives = @adjectives[adj_key]
      nouns = @nouns[noun_key]

      name =
        Enum.join([
          adjectives
          |> Enum.at(:random.uniform(@adjectives_length[adj_key])-1)
          |> String.capitalize(),

          nouns
          |> Enum.at(:random.uniform(@nouns_length[noun_key])-1)
          |> String.capitalize(),
        ])

      {:msg, name}
    end
  end
end
