import Config

# The spec that `mix prism.gen.web` generates from, and where the files go: the
# repository root, where npm publishes them from.
config :prism_dsl, spec: Prism.Tokens, out: ".."
