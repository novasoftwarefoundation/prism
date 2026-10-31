defmodule PrismDsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism_dsl,
      version: "0.1.0",
      description: "A schema DSL for design tokens, and generators for each platform",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger, :eex]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
