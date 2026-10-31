defmodule Prism.Generator.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism_generator,
      version: "0.2.0",
      description:
        "A design format for tokens, and generators that turn a design into code per target",
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
