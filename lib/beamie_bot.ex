defmodule BeamieBot do
  use Application

  def start(_type, _args) do
    Bot.run
    {:ok, self()}
  end
end

defmodule Bot do
  def run do
    Chatty.add_privmsg_hook :issue, &IssueHook.run/3#, channel: "elixir-lang"
    Chatty.add_privmsg_hook :doc, &DocHook.run/3#, channel: "elixir-lang"
    Chatty.add_privmsg_hook :link, &LinkHook.run/3, direct: true#, channel: "elixir-lang"
    Chatty.add_privmsg_hook :linkscan, &LinkScanHook.run/3#, channel: "elixir-lang"
    Chatty.add_privmsg_hook :trivia, &TriviaHook.run/3#, channel: "elixir-lang"
    Chatty.add_privmsg_hook :ping, &PingHook.run/3, direct: true
    Chatty.add_privmsg_hook :eval, &EvalHook.run/3
    Chatty.add_privmsg_hook :module_name, &ModuleNameHook.run/3, direct: true
    Chatty.add_privmsg_hook :hex, &HexHook.run/3

    # this one has to be last
    Chatty.add_privmsg_hook :rudereply, &RudeReplyHook.run/3, direct: true, exclusive: true
  end
end

