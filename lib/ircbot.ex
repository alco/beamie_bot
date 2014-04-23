defmodule Ircbot do
  use Application.Behaviour

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  def start(_type, _args) do
    :random.seed(:erlang.now())
    Bot.run
    #Ircbot.Supervisor.start_link
    {:ok, self()}
  end
end

defmodule Bot do
  def run do
    IRCBot.Connection.start_link
    IRCBot.Connection.add_hook :issue, &IssueHook.run/2, in: :text
    IRCBot.Connection.add_hook :doc, &DocHook.run/2, in: :text
    IRCBot.Connection.add_hook :link, &LinkHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :linkscan, &LinkScanHook.run/2, in: :text
    IRCBot.Connection.add_hook :trivia, &TriviaHook.run/2, in: :text
    IRCBot.Connection.add_hook :ping, &PingHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :likewhat, &LikeWhatHook.run/2, in: :text, direct: true
    IRCBot.Connection.add_hook :eval, &EvalHook.run/2, in: :text
    IRCBot.Connection.add_hook :module_name, &ModuleNameHook.run/2, in: :text, direct: true

    # this one has to be last
    IRCBot.Connection.add_hook :rudereply, &RudeReplyHook.run/2, in: :text, direct: true, exclusive: true
  end
end

