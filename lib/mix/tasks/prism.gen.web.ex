defmodule Mix.Tasks.Prism.Gen.Web do
  @shortdoc "Generates the Tailwind preset and base CSS from the spec"
  @moduledoc """
      mix prism.gen.web [--out PATH]

  Writes `tailwind.preset.js` and `css/base.css` under PATH (default: the repo
  root, where npm publishes them from). A hand-written file is never
  overwritten. `css/components.css` is still hand-written.
  """
  use Mix.Task

  @requirements ["compile"]

  @impl true
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: [out: :string])

    if rest != [],
      do: Mix.raise("unexpected argument #{Enum.join(rest, " ")}; use --out PATH")

    out = opts[:out] || "."

    for {path, source} <- Prism.Gen.Web.generate(Prism.Tokens.__schema__()) do
      path = Path.join(out, path)
      File.mkdir_p!(Path.dirname(path))
      Prism.Gen.write!(path, source)
    end
  end
end
