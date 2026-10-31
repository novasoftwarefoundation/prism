defmodule Mix.Tasks.Prism.Gen.Web do
  @shortdoc "Generates the Tailwind preset and base CSS from a design"
  @moduledoc """
      mix prism.gen.web [--design MODULE] [--out PATH]

  Writes `tailwind.preset.js` and `css/base.css` under PATH from the design
  MODULE, a module that uses `Prism.Generator.Schema`. Without the options,
  both come from the config (PATH defaults to the current directory):

      config :prism, design: MyApp.Design, out: "targets/web"

  A hand-written file is never overwritten.
  """
  use Mix.Task

  alias Prism.Generator.{Web, Writer}

  @requirements ["compile"]

  @impl true
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: [out: :string, design: :string])

    if rest != [],
      do: Mix.raise("unexpected argument #{Enum.join(rest, " ")}; use --out PATH")

    out = opts[:out] || Application.get_env(:prism, :out, ".")

    for {path, source} <- Web.generate(design!(opts[:design]).__schema__()) do
      path = Path.join(out, path)
      File.mkdir_p!(Path.dirname(path))
      Writer.write!(path, source)
    end
  end

  defp design!(name) do
    module =
      case name || Application.get_env(:prism, :design) do
        nil -> Mix.raise("no design: pass --design MODULE or set config :prism, design: MODULE")
        name when is_binary(name) -> Module.concat([name])
        module when is_atom(module) -> module
      end

    unless Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 0),
      do:
        Mix.raise(
          "#{inspect(module)} is not a design (a module that uses Prism.Generator.Schema)"
        )

    module
  end
end
