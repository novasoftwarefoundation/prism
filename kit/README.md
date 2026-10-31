# prism_kit

A schema DSL for design tokens, and generators that turn a spec written in it into platform code. The kit is generic: it knows no particular design system.

- `lib/prism_kit/schema.ex`: the DSL (`use PrismKit.Schema`) and its compile-time checks
- `lib/prism_kit/gen/web.ex`: the web generator (a Tailwind preset and base CSS)
- `lib/mix/tasks/prism.gen.web.ex`: `mix prism.gen.web`
- `docs/adr/`: decisions, starting with [0001: spec format](docs/adr/0001-spec-format.md)

## Use

A design system is a Mix project that depends on the kit, writes its spec in a module that uses `PrismKit.Schema`, and names it in its config:

```elixir
# mix.exs
deps: [{:prism_kit, path: "kit"}]

# .formatter.exs: write the DSL without parentheses
[import_deps: [:prism_kit], ...]

# config/config.exs
config :prism_kit, spec: MyApp.Tokens
```

```sh
mix prism.gen.web                          # the spec from the config, into the current directory
mix prism.gen.web --spec MyApp.Tokens --out priv/web
```

## Develop

```sh
mix test
```

The tests use their own fixture spec (`test/support/fixture_spec.ex`) and compare its output with the reviewed snapshot in `test/fixtures/web/`.

## Moving to its own repository

The kit depends on nothing outside this folder. To move it, move `kit/` into a repository of its own, and change the dependency line in the design system's `mix.exs` from `{:prism_kit, path: "kit"}` to a git dependency (`{:prism_kit, git: "<url>", tag: "<version>"}`) or a Hex package.
