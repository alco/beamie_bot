defmodule BeamieBot do
  use Application

  def start(_type, _args) do
    Bot.run
    {:ok, self()}
  end
end

defmodule Bot do
  def run do
    Chatty.add_hook :issue, &IssueHook.run/2, in: :text, channel: "elixir-lang"
    Chatty.add_hook :doc, &DocHook.run/2, in: :text, channel: "elixir-lang"
    Chatty.add_hook :link, &LinkHook.run/2, in: :text, direct: true, channel: "elixir-lang"
    Chatty.add_hook :linkscan, &LinkScanHook.run/2, in: :text, channel: "elixir-lang"
    Chatty.add_hook :trivia, &TriviaHook.run/2, in: :text, channel: "elixir-lang"
    Chatty.add_hook :ping, &PingHook.run/2, in: :text, direct: true
    Chatty.add_hook :eval, &EvalHook.run/2, in: :text
    Chatty.add_hook :module_name, &ModuleNameHook.run/2, in: :text, direct: true
    Chatty.add_hook :hex, &HexHook.run/2, in: :text

    # this one has to be last
    Chatty.add_hook :rudereply, &RudeReplyHook.run/2, in: :text, direct: true, exclusive: true
  end
end

