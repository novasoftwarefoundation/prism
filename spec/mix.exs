defmodule PrismSpec.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism_spec,
      version: "0.1.7",
      description: "The Prism style: design tokens and the files generated from them",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: [{:prism_dsl, path: "../dsl"}]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
