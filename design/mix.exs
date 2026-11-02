defmodule Prism.Design.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism_design,
      # The same version as targets/web/package.json; a test checks it.
      version: "0.2.0",
      description: "Prism's design",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Phoenix only for the test that renders Prism's components through
  # `Prism.Generator.Phoenix`; the design itself needs none.
  defp deps do
    [
      {:prism_generator, path: "../generator"},
      {:phoenix_live_view, "~> 1.1", only: :test}
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
