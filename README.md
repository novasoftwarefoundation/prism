# Prism

A Tailwind-based UI framework for scientific software, published on npm as `@novasoftwarefoundation/prism`.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

To use Prism in an app, see the package's README: [targets/web/README.md](targets/web/README.md) (install, Tailwind preset, CSS, classes). A Phoenix app also gets Prism's components as function components; see [Use it in a Phoenix app](#use-it-in-a-phoenix-app). A React app gets them from `@novasoftwarefoundation/prism-react`; see [Use it in a React app](#use-it-in-a-react-app).

## Layout

Prism's look is written once, as a design in Elixir, and generated into code for each target: an app platform, or later a design tool. The top of the repository shows the split:

| Folder | What |
|---|---|
| `design/` | Prism's design, a Mix project (`:prism_design`): `lib/tokens.ex` (`Prism.Design.Tokens`), `lib/components.ex` (`Prism.Design.Components`, which takes the tokens and is the whole design), `config/config.exs` (the design module and the folder of each target), and its checks: the 0.1.7 golden test, the version check, the font roles, the type styles, the components. |
| `generator/` | The generic part, a Mix project of its own (`:prism_generator`): the design format (`lib/schema.ex`, with components in `lib/schema/components.ex`), the header of generated files (`lib/header.ex`), the web target (`lib/web.ex`, its templates in `lib/web/`, the component mechanics in `lib/web/components.ex`, the class names in `lib/web/classes.ex`, and the components' markup in `lib/web/elements.ex`), the Phoenix components (`lib/phoenix.ex`, `Prism.Generator.Phoenix`), the React target (`lib/react.ex`, `Prism.Generator.React`), and `mix prism.gen` (`lib/mix/tasks/prism.gen.ex`). It knows nothing about Prism's values. |
| `targets/web/` | The npm package `@novasoftwarefoundation/prism`: `package.json`, the generated `tailwind.preset.js`, `css/base.css` and `css/components.css`, and `fonts/`. |
| `targets/react/` | The npm package `@novasoftwarefoundation/prism-react`: `package.json`, `tsconfig.json`, the generated components in `src/`, and their tests in `test/`. Later `targets/swift/`. |

`design/` depends on `generator/` with `{:prism_generator, path: "../generator"}`; there is no Mix project at the root. Decisions are in `docs/adr/`: [0001: design format](docs/adr/0001-design-format.md), [0002: Prism's design](docs/adr/0002-prism-design.md), [0003: Phoenix components at compile time](docs/adr/0003-phoenix-components.md) and [0004: React components](docs/adr/0004-react-components.md).

## Change the design

`targets/web/tailwind.preset.js`, `targets/web/css/base.css`, `targets/web/css/components.css` and `targets/react/src/` are generated: don't edit them by hand. Change `design/lib/tokens.ex` (tokens) or `design/lib/components.ex` (components), then regenerate and commit the result. An app adjusts a component through the component's own API, never by editing a generated file.

```sh
cd design
mix deps.get
mix prism.gen   # writes every target: ../targets/web (the preset and the CSS) and ../targets/react/src
mix test
```

`mix test` includes a golden test (`design/test/golden_test.exs`): the generated files must equal prism 0.1.7, with the component classes renamed by the test's table of 0.1.7 → 0.2.0 classes, apart from each file's header line and the reviewed diff in `design/test/golden/0.1.7.diff`. CI runs `mix prism.gen --check`, which fails when a committed file differs from what the design generates.

## Use it in a Phoenix app

An Elixir app reads the design itself, so it needs no generated files: a module of the app's own gets one function component per design component while the app compiles. The app depends on the design, from the `design/` folder of this repository, and on Phoenix LiveView:

```elixir
# mix.exs
defp deps do
  [
    {:prism_design,
     git: "https://github.com/novasoftwarefoundation/prism.git", tag: "v0.2.0", subdir: "design"},
    {:phoenix_live_view, "~> 1.1"}
  ]
end
```

The design brings the generator with it. An app that adds LiveView after its first compile has a build of the generator without `Prism.Generator.Phoenix`; rebuild it once with `mix deps.compile prism_generator --force`.

```elixir
defmodule MyAppWeb.Prism do
  use Prism.Generator.Phoenix, design: Prism.Design.Components
end
```

```heex
<MyAppWeb.Prism.button variant={:primary} tone={:danger} loading={@saving} phx-click="save">
  Save
  <:icon><span class="hero-check"></span></:icon>
</MyAppWeb.Prism.button>

<MyAppWeb.Prism.field>
  <:label for="email">Email</:label>
  <MyAppWeb.Prism.text_field id="email" name="email" invalid={@errors != []} />
  <:error_message :for={error <- @errors}>{error}</:error_message>
</MyAppWeb.Prism.field>

<MyAppWeb.Prism.tag tone={:success}>Done</MyAppWeb.Prism.tag>
```

- **Axes** (`variant`, `tone`, `size`, `status`) are atom attributes with the design's values, so Phoenix warns at compile time about `variant={:primray}`. Without one, an axis has the design's default: a button's tone is accent and a spinner's size medium (no class), a tag's tone is `:accent`, a message bar's `:info`, a step's `:incomplete`. A button's `variant` and a spinner's color have no default.
- **States the app sets** are boolean attributes: `loading`, `invalid`, `disabled`, `checked`. On a form control, `disabled` and `checked` set the element's own attribute; elsewhere a state adds its class (`prism-radio--disabled`). The browser's states (pressed, hovered, focused) need nothing.
- **Parts** follow the design's order: the label is the inner block, the icon a `<:icon>` slot (with it, the button gets `prism-button--with-icon`), and the spinner shows while `loading`.
- **Adjusting**: `class` adds the app's classes after the component's own, and other attributes (`id`, `phx-*`, `type`, `name`, …) go on the element. A button's element is `as`: `"button"` by default, or `"a"`, `"span"` or `"div"` when the app wraps it in its own action; any other value warns at compile time and fails when it renders. What a component does stays in the app.

`Prism.Generator.Phoenix` exists only when the app has Phoenix LiveView (`~> 1.1`); the design itself has no Phoenix. The class names come from the same functions as `components.css`, so the components and the CSS can't drift apart, and a design change reaches the app with the dependency bump: Mix recompiles the module. Its moduledoc lists each component's element and slots.

## Use it in a React app

A React app installs the components and the CSS, at the same version (the CSS package is a peer dependency):

```sh
npm install @novasoftwarefoundation/prism-react @novasoftwarefoundation/prism
```

```css
/* the app's main stylesheet */
@import "@novasoftwarefoundation/prism/css/base.css";
@import "@novasoftwarefoundation/prism/css/components.css";
```

```tsx
import { Button, Field, Tag, TextField } from "@novasoftwarefoundation/prism-react";

<Button variant="primary" tone="danger" loading={saving} icon={<CheckIcon />} onClick={save}>
  Save
</Button>

<Field label="Email" labelProps={{ htmlFor: "email" }} errorMessage={errors[0]}>
  <TextField id="email" name="email" invalid={errors.length > 0} />
</Field>

<Tag tone="success">Done</Tag>
```

The props follow the same rules as the Phoenix components: axes are props typed from the design (TypeScript rejects `variant="primray"`), with the design's defaults; the app's states are boolean props; parts come in the design's order (`children` is the label, `icon` adds `prism-button--with-icon`, the spinner shows while `loading`); `className` appends, and the other props and the ref go on the element. The package's README ([targets/react/README.md](targets/react/README.md)) has the details. The components are generated into `targets/react/src/` and built with `tsc` into ES modules and type declarations; React 18 and 19 work.

## The generator

- The schema turns a design into plain data, `__schema__/0`, whose shape is documented in `Prism.Generator.Schema`. The targets read only that data, never the schema's internals; a test checks that no other file calls into the schema.
- A component's look is shared by every target. Each target's mechanics (for the web: display, cursors, focus outlines, keyframes, the check mark) are in the generator, and a value that really differs per platform is a `web:`, `ios:` or `android:` binding in the design; see ADR 0001, decision 3.
- `mix prism.gen` generates every target named in the config (today `web` and `react`), puts a `Prism.Generator.Header` line on each file, and never overwrites a file without one. A later target adds a module and its templates, not a task.
- `Prism.Generator.Phoenix` is no file target: an app's module `use`s it and gets its components at compile time (ADR 0003). Phoenix LiveView is an optional dependency of the generator; CI compiles the generator without it too (`mix compile --no-optional-deps`). The web target, the Phoenix components and the React target share `Prism.Generator.Web.Classes` for class names, and the two kinds of components share `Prism.Generator.Web.Elements` for their markup.
- The generator gets the design only from the config, never by naming it. It compiles and tests on its own, without `design/`, so a reference to Prism's design fails its build. CI also checks that it mentions none of Prism's values.
- Its tests use neutral example designs: `generator/test/support/example_design.ex`, whose files they compare with reviewed fixtures in `generator/test/fixtures/`, and `example_components.ex`, one component of every kind, which they render through `Prism.Generator.Phoenix` and check against its CSS. Its React components are a fixture package too, `generator/test/fixtures/react/`, whose `npm test` type-checks them and renders them against the example's CSS (`generator/test/fixtures/example_components/`).
- **Moving it to its own repository:** move `generator/` out as it is, and change one line in `design/mix.exs` from `path: "../generator"` to a git or Hex dependency.

## Publish

Install Prism from npm. The repository root is no longer the package (it lives in `targets/web/`), so installing from git or linking to files at the root of the repository no longer works.

Publishing to npm is manual for now, from `targets/web/` and `targets/react/`, with the same version for both:

1. Bump the version in `design/mix.exs`, `targets/web/package.json`, and in `targets/react/package.json` both its version and its peer dependency on `@novasoftwarefoundation/prism`. Then update the React package's lockfile: `cd targets/react && npm install --package-lock-only`. A test checks that all of them are equal. Merge it.
2. Check the packages: `cd targets/web && npm pack --dry-run` lists the files in `.github/npm-files.txt`, and `cd targets/react && npm ci && npm pack --dry-run` (which builds `dist/`) those in `.github/npm-files-react.txt`.
3. Publish the CSS first, since the components depend on it: `cd targets/web && npm publish --access public`.
4. Then the components: `cd targets/react && npm publish --access public`.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
