defmodule DocHook do
  @moduledoc """
  This hook is responsible for scanning each message on the presence of
  documentation references.

  A doc reference can take one of the following forms:

      doc Kernel
      doc Kernel.spawn
      doc Kernel.spawn/2
      doc +
      doc +/2

  """

  def run(text, _sender, _chan) do
    mid_frag = "[A-Z][[:alnum:]_]*"
    mid = "#{mid_frag}(?:\.#{mid_frag})*"
    fid = "[^A-Z](?:[^/[:space:].]|/(?!\\d))*"

    module_re = ~r"(?<= |^)doc (#{mid})(?= |$)"
    fun_re    = ~r"(?<= |^)doc (#{fid})(?:/(\d))?(?= |$)"
    mfa_re    = ~r"(?<= |^)doc (#{mid})\.(#{fid})(?:/(\d))?(?= |$)"

    result = extract_module_doc(module_re, text)
          || extract_local_doc(fun_re, text)
          || extract_mfa_doc(mfa_re, text)
    result && Enum.map(result, fn text -> {:msg, text} end)
  end

  defp extract_module_doc(re, text) do
    modname = case Regex.run(re, text) do
      [_, modname] ->
        mod = Module.concat([modname])
        case Code.ensure_loaded?(mod) && Code.get_docs(mod, :moduledoc) do
          {_, doc} -> doc && modname
          _        -> nil
        end
      _ -> nil
    end
    modname && [make_module_url(modname)]
  end

  defp extract_local_doc(re, text) do
    case Regex.run(re, text) do
      [_, fname] ->
        process_module("Kernel", fname, :all)
      [_, fname, arity] ->
        process_module("Kernel", fname, String.to_integer(arity))
      _ -> nil
    end
  end

  defp extract_mfa_doc(re, text) do
    case Regex.run(re, text) do
      [_, modname, fname] ->
        process_module(modname, fname, :all)
      [_, modname, fname, arity] ->
        process_module(modname, fname, String.to_integer(arity))
      _ -> nil
    end
  end

  defp process_module(modname, fname, arity) do
    mod = Module.concat([modname])
    fun = try do
      String.to_existing_atom(fname)
    rescue
      ArgumentError -> nil
    end
    arities = Code.ensure_loaded?(mod) && check_arity_doc(mod, fun, arity)
    arities && Enum.map(arities, fn arity -> make_mfa_url(modname, fname, arity) end)
  end

  defp check_arity_doc(mod, fun, :all) do
    Keyword.get_values(mod.__info__(:functions), fun)  # get all arities of fun
    |> Stream.map(fn arity -> check_doc(mod, fun, arity) end)
    |> Enum.reject(&(nil == &1))
  end

  defp check_arity_doc(mod, fun, arity) do
    arity = check_doc(mod, fun, arity)
    arity && [arity]
  end

  defp check_doc(mod, fun, arity) do
    case List.keyfind(Code.get_docs(mod, :docs), {fun, arity}, 0) do
      {_fun, _line, _typ, _args, doc} ->
        doc && arity
      _ -> nil
    end
  end

  defp make_module_url(modname) do
    "http://elixir-lang.org/docs/stable/#{section(modname)}/#{modname}.html"
  end

  defp make_mfa_url(modname, fname, arity) do
    "http://elixir-lang.org/docs/stable/#{section(modname)}/#{modname}.html##{fname}/#{arity}"
  end

  defp section(modname) do
    comps = String.split(modname, ".")
    case String.downcase(hd(comps)) do
      x when x in ["mix", "iex", "eex", "exunit"] -> x
      _ -> "elixir"
    end
  end
end
