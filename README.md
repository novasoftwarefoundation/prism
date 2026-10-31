# Prism

A Tailwind-based UI framework for scientific software, published on npm as `@novasoftwarefoundation/prism`.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

To use Prism in an app, see the package's README: [targets/web/README.md](targets/web/README.md) (install, Tailwind preset, CSS, classes).

## Layout

Prism's look is written once, as a design in Elixir, and generated into code for each target: an app platform, or later a design tool. The repository is one Mix project with three layers:

| Layer | Where | What |
|---|---|---|
| Generator | `lib/generator/`, `test/generator/` | Generic: the schema a design is written in (`Prism.Generator.Schema`), the web generator and its templates, and the Mix tasks in `lib/generator/mix/tasks/` (one file per task: `prism.gen.web.ex`). It knows nothing about Prism's values. |
| Design | `lib/design/`, `test/design/` | Prism's design: `Prism.Design.Tokens`, and its checks (the 0.1.7 golden test, the version check, the font roles). |
| Targets | `targets/web/` | The npm package: `package.json`, the generated `tailwind.preset.js` and `css/base.css`, the hand-written `css/components.css`, and `fonts/`. Later `targets/swift/`. |

`config/config.exs` names the design and where its output goes. Decisions are in `docs/adr/`: [0001: design format](docs/adr/0001-design-format.md) and [0002: Prism's design](docs/adr/0002-prism-design.md).

## Change the design

`targets/web/tailwind.preset.js` and `targets/web/css/base.css` are generated: don't edit them by hand. Change `lib/design/tokens.ex`, then regenerate and commit the result:

```sh
mix prism.gen.web   # writes targets/web/tailwind.preset.js and targets/web/css/base.css
mix test
```

`mix test` includes a golden test: the output must equal prism 0.1.7 apart from each file's header line and the reviewed diff in `test/design/golden/0.1.7.diff`. CI fails when the committed files differ from what the design generates. `css/components.css` is still hand-written.

## The generator

- The schema turns a design into plain data, `__schema__/0`, whose shape is documented in `Prism.Generator.Schema`. The generators read only that data, never the schema's internals; a test checks that no generator calls into the schema.
- The generator gets the design only from `--design MODULE` or `config :prism, design: MODULE`, never by naming it. CI fails when any file in `lib/generator/`, subfolders included, depends on `lib/design/`, directly or through another file (`mix xref graph`, see `.github/scripts/generator-boundary.sh`), or when the generator's files mention Prism's values or the path `lib/design`.
- Its tests use a neutral example design (`test/generator/support/example_design.ex`) and compare its output with reviewed fixtures in `test/generator/fixtures/`.
- **Moving it to its own repository:** move `lib/generator/` and `test/generator/` into a new Mix project (where `lib/generator/mix/tasks/` becomes `lib/mix/tasks/`), and add one dependency line to this project's `mix.exs`, e.g. `{:prism_generator, git: "<url>", tag: "<version>"}`.

## Publish

Install Prism from npm. The repository root is no longer the package (it lives in `targets/web/`), so installing from git or linking to files at the root of the repository no longer works.

Publishing to npm is manual for now, from `targets/web/`:

1. Bump the version in `mix.exs` and `targets/web/package.json` (a test checks they are equal) and merge it.
2. Check the package: `cd targets/web && npm pack --dry-run` lists the files in `.github/npm-files.txt`.
3. Publish: `cd targets/web && npm publish --access public`.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
