# prism_dsl

The language of a style spec: a schema DSL for design tokens, and generators that turn a spec written in it into platform code. It is generic: it knows no particular design system.

- `lib/prism_dsl/schema.ex`: the DSL (`use PrismDsl.Schema`) and its compile-time checks
- `lib/prism_dsl/gen/web.ex`: the web generator (a Tailwind preset and base CSS)
- `lib/mix/tasks/prism.gen.web.ex`: `mix prism.gen.web`
- `docs/adr/`: decisions, starting with [0001: spec format](docs/adr/0001-spec-format.md)

## Inside the DSL

The schema (`PrismDsl.Schema`) turns a spec into plain data: `__schema__/0`, whose shape is documented in the schema's moduledoc. The generators (`PrismDsl.Gen.*` and the `prism.gen.*` tasks) read only that data, never the schema's internals, so either side can change on its own as long as the data stays the same. A test checks that no generator refers to `PrismDsl.Schema`.

## Use

A spec is a Mix project that depends on the DSL, writes its spec in a module that uses `PrismDsl.Schema`, and names it in its config:

```elixir
# mix.exs
deps: [{:prism_dsl, path: "../dsl"}]

# .formatter.exs: write the DSL without parentheses
[import_deps: [:prism_dsl], ...]

# config/config.exs: the spec module, and where the generated files go
config :prism_dsl, spec: MyApp.Tokens, out: ".."
```

```sh
mix prism.gen.web                          # spec and output folder from the config
mix prism.gen.web --spec MyApp.Tokens --out priv/web
```

## Develop

```sh
mix test
```

The tests use their own fixture spec (`test/support/fixture_spec.ex`) and compare its output with the reviewed snapshot in `test/fixtures/web/`.

## Moving to its own repository

The DSL depends on nothing outside this folder. To move it, move `dsl/` into a repository of its own, and change one dependency line in the spec's `mix.exs` from `{:prism_dsl, path: "../dsl"}` to a git dependency (`{:prism_dsl, git: "<url>", tag: "<version>"}`) or a Hex package.
