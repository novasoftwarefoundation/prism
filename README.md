# Prism

A Tailwind-based UI framework for scientific software, published on npm as `@novasoftwarefoundation/prism`.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

To use Prism in an app, see the package's README: [targets/web/README.md](targets/web/README.md) (install, Tailwind preset, CSS, classes).

## Layout

Prism's look is written once, as a design in Elixir, and generated into code for each target: an app platform, or later a design tool. The top of the repository shows the split:

| Folder | What |
|---|---|
| `design/` | Prism's design, a Mix project (`:prism_design`): `lib/tokens.ex` (`Prism.Design.Tokens`), `lib/components.ex` (`Prism.Design.Components`, which takes the tokens and is the whole design), `config/config.exs` (the design module and the folder of each target), and its checks: the 0.1.7 golden test, the version check, the font roles, the type styles, the components. |
| `generator/` | The generic part, a Mix project of its own (`:prism_generator`): the design format (`lib/schema.ex`, with components in `lib/schema/components.ex`), the header of generated files (`lib/header.ex`), the web target (`lib/web.ex`, its templates in `lib/web/`, and the component mechanics in `lib/web/components.ex`), and `mix prism.gen` (`lib/mix/tasks/prism.gen.ex`). It knows nothing about Prism's values. |
| `targets/web/` | The npm package: `package.json`, the generated `tailwind.preset.js`, `css/base.css`, `css/components.css` and `images/spinner.svg`, and `fonts/`. Later `targets/swift/`. |

`design/` depends on `generator/` with `{:prism_generator, path: "../generator"}`; there is no Mix project at the root. Decisions are in `docs/adr/`: [0001: design format](docs/adr/0001-design-format.md) and [0002: Prism's design](docs/adr/0002-prism-design.md).

## Change the design

`targets/web/tailwind.preset.js`, `targets/web/css/base.css`, `targets/web/css/components.css` and `targets/web/images/spinner.svg` are generated: don't edit them by hand. Change `design/lib/tokens.ex` (tokens) or `design/lib/components.ex` (components), then regenerate and commit the result. An app adjusts a component through the component's own API, never by editing a generated file.

```sh
cd design
mix deps.get
mix prism.gen   # writes every target: ../targets/web/tailwind.preset.js, css/base.css, css/components.css and images/spinner.svg
mix test
```

`mix test` includes a golden test (`design/test/golden_test.exs`): the generated files must equal prism 0.1.7, with the component classes renamed by the test's table of 0.1.7 → 0.2.0 classes, apart from each file's header line and the reviewed diff in `design/test/golden/0.1.7.diff`. CI runs `mix prism.gen --check`, which fails when a committed file differs from what the design generates.

## The generator

- The schema turns a design into plain data, `__schema__/0`, whose shape is documented in `Prism.Generator.Schema`. The targets read only that data, never the schema's internals; a test checks that no other file calls into the schema.
- A component's look is shared by every target. Each target's mechanics (for the web: display, cursors, focus outlines, keyframes, the check mark) are in the generator, and a value that really differs per platform is a `web:`, `ios:` or `android:` binding in the design; see ADR 0001, decision 3.
- `mix prism.gen` generates every target named in the config (today `web`), puts a `Prism.Generator.Header` line on each file, and never overwrites a file without one. A later target adds a module and its templates, not a task.
- The generator gets the design only from the config, never by naming it. It compiles and tests on its own, without `design/`, so a reference to Prism's design fails its build. CI also checks that it mentions none of Prism's values.
- Its tests use a neutral example design (`generator/test/support/example_design.ex`) and compare its files with reviewed fixtures in `generator/test/fixtures/`.
- **Moving it to its own repository:** move `generator/` out as it is, and change one line in `design/mix.exs` from `path: "../generator"` to a git or Hex dependency.

## Publish

Install Prism from npm. The repository root is no longer the package (it lives in `targets/web/`), so installing from git or linking to files at the root of the repository no longer works.

Publishing to npm is manual for now, from `targets/web/`:

1. Bump the version in `design/mix.exs` and `targets/web/package.json` (a test checks they are equal) and merge it.
2. Check the package: `cd targets/web && npm pack --dry-run` lists the files in `.github/npm-files.txt`.
3. Publish: `cd targets/web && npm publish --access public`.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
