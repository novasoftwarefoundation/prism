import Config

# The design that `mix prism.gen.web` generates from, and where the files go:
# targets/web, where npm publishes them from.
config :prism, design: Prism.Design.Tokens, out: "targets/web"
