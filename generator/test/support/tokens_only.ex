defmodule Prism.Generator.TokensOnly do
  @moduledoc false
  # A design with tokens only, for a design that takes its tokens from another.
  use Prism.Generator.Schema

  web prefix: "only", fonts_url: "../fonts"

  color :ink, "#101010"
  radius :default, 4
end
