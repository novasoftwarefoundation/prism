defmodule Mix.Tasks.Prism.Gen.Web do
  @shortdoc "Generates the Tailwind preset and base CSS from a spec"
  @moduledoc """
      mix prism.gen.web [--spec MODULE] [--out PATH]

  Writes `tailwind.preset.js` and `css/base.css` under PATH from the spec
  MODULE, a module that uses `PrismDsl.Schema`. Without the options, both come
  from the project's config (PATH defaults to the current directory):

      config :prism_dsl, spec: MyApp.Tokens, out: ".."

  A hand-written file is never overwritten.
  """
  use Mix.Task

  @requirements ["compile"]

  @impl true
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: [out: :string, spec: :string])

    if rest != [],
      do: Mix.raise("unexpected argument #{Enum.join(rest, " ")}; use --out PATH")

    out = opts[:out] || Application.get_env(:prism_dsl, :out, ".")

    for {path, source} <- PrismDsl.Gen.Web.generate(spec!(opts[:spec]).__schema__()) do
      path = Path.join(out, path)
      File.mkdir_p!(Path.dirname(path))
      PrismDsl.Gen.write!(path, source)
    end
  end

  defp spec!(name) do
    module =
      case name || Application.get_env(:prism_dsl, :spec) do
        nil -> Mix.raise("no spec: pass --spec MODULE or set config :prism_dsl, spec: MODULE")
        name when is_binary(name) -> Module.concat([name])
        module when is_atom(module) -> module
      end

    unless Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 0),
      do: Mix.raise("#{inspect(module)} is not a spec (a module that uses PrismDsl.Schema)")

    module
  end
end
