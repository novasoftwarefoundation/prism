defmodule Prism.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism,
      version: "0.1.7",
      description: "Spec and generators for the Prism style",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger, :eex]]
  end
end
