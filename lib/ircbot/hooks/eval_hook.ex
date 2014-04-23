defmodule EvalHook do
  def run(_sender, msg) do
    case msg do
      "eval~ " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), version: "latest")}

      "eval~0.13.0 " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), version: "v0.13.0")}

      "eval~0.12.5 " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), version: "v0.12.5")}

      "erleval~ " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), lang: "erlang", version: "17.0")}

      "erleval~r16 " <> expr ->
        {:msg, Evaluator.eval(String.strip(expr), lang: "erlang", version: "R16B03-1")}

      _ -> nil
    end
  end
end
