defmodule Prism.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism,
      # The same version as clients/web/package.json; a test checks it.
      version: "0.1.7",
      description: "Prism's design, and the generator that turns it into client code",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger, :eex]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/generator/support"]
  defp elixirc_paths(_), do: ["lib"]
end
