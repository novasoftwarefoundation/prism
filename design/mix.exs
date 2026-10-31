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
      deps: [{:prism_generator, path: "../generator"}]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
