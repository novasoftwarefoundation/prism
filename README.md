# Prism

A Tailwind-based UI framework for scientific software, published on npm as `@novasoftwarefoundation/prism`.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

To use Prism in an app, see the package's README: [targets/web/README.md](targets/web/README.md) (install, Tailwind preset, CSS, classes). A Phoenix app also gets Prism's components as function components; see [Use it in a Phoenix app](#use-it-in-a-phoenix-app). A React app gets them from `@novasoftwarefoundation/prism-react`; see [Use it in a React app](#use-it-in-a-react-app). A design tool gets the tokens and an overview of the design; see [Use it in a design tool](#use-it-in-a-design-tool).

## Layout

Prism's look is written once, as a design in Elixir, and generated into code for each target: an app platform, or a design tool. The top of the repository shows the split:

| Folder | What |
|---|---|
| `design/` | Prism's design, a Mix project (`:prism_design`): `lib/tokens.ex` (`Prism.Design.Tokens`), `lib/components.ex` (`Prism.Design.Components`, which takes the tokens and is the whole design), `config/config.exs` (the design module and the folder of each target), and its checks: the 0.1.7 golden test, the version check, the font roles, the typography, the components. |
| `generator/` | The generic part, a Mix project of its own (`:prism_generator`): the design format (`lib/schema.ex`, with components in `lib/schema/components.ex`), the header of generated files (`lib/header.ex`), the web target (`lib/web.ex`, its templates in `lib/web/`, the component mechanics in `lib/web/components.ex`, the class names in `lib/web/classes.ex`, and the components' markup in `lib/web/elements.ex`), the Phoenix components (`lib/phoenix.ex`, `Prism.Generator.Phoenix`), the React target (`lib/react.ex`, `Prism.Generator.React`), the design-tool target (`lib/design_tools.ex`, `Prism.Generator.DesignTools`, with the overview in `lib/design_tools/overview.ex`), and `mix prism.gen` (`lib/mix/tasks/prism.gen.ex`). It knows nothing about Prism's values. |
| `targets/web/` | The npm package `@novasoftwarefoundation/prism`: `package.json`, the generated `tailwind.preset.js`, `css/base.css` and `css/components.css`, and `fonts/`. |
| `targets/react/` | The npm package `@novasoftwarefoundation/prism-react`: `package.json`, `tsconfig.json`, the generated components in `src/`, and their tests in `test/`. Later `targets/swift/`. |
| `targets/design-tools/` | Files for design tools, attached to each release: the generated `tokens.json` (DTCG), `tokens.css` (CSS custom properties) and `overview.svg`, and their checks (`package.json`, `test/`). |

`design/` depends on `generator/` with `{:prism_generator, path: "../generator"}`; there is no Mix project at the root. Decisions are in `docs/adr/`: [0001: design format](docs/adr/0001-design-format.md), [0002: Prism's design](docs/adr/0002-prism-design.md), [0003: Phoenix components at compile time](docs/adr/0003-phoenix-components.md), [0004: React components](docs/adr/0004-react-components.md), [0005: files for design tools](docs/adr/0005-design-tools.md), [0006: button looks](docs/adr/0006-button-looks.md) and [0007: spinner sizes and progress](docs/adr/0007-spinner-sizes-progress.md).

## Change the design

`targets/web/tailwind.preset.js`, `targets/web/css/base.css`, `targets/web/css/components.css`, `targets/react/src/` and the three files in `targets/design-tools/` are generated: don't edit them by hand. Change `design/lib/tokens.ex` (tokens) or `design/lib/components.ex` (components), then regenerate and commit the result. An app adjusts a component through the component's own API, never by editing a generated file.

```sh
cd design
mix deps.get
mix prism.gen   # writes every target: ../targets/web (the preset and the CSS), ../targets/react/src and ../targets/design-tools
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

<MyAppWeb.Prism.button variant={:plain} padded={false} icon_position={:end}>
  Next
  <:icon><span class="hero-arrow-right"></span></:icon>
</MyAppWeb.Prism.button>
```

- **Axes** (`variant`, `tone`, `size`, `status`) are atom attributes with the design's values (a spinner's `size` an integer), so Phoenix warns at compile time about `variant={:primray}`. Without one, an axis has the design's default: a button's tone is accent and a spinner's size 24 (no class), a tag's tone is `:accent`, a message bar's `:info`, a step's `:incomplete`. A button's `variant` and a spinner's color have no default.
- **Spinners** ([ADR 0007](docs/adr/0007-spinner-sizes-progress.md)): `size` is an integer, the spinner's px: `16`, `20`, `24` (the default) or `32` (`size={16}`). `progress`, a number from 0 to 100 or `nil`, shows a light grey ring with an arc in the spinner's color as long as the value (clamped to 0..100), with `role="progressbar"` and the ARIA values; the spinner keeps turning. A loading button's spinner is 20px.
- **Buttons** ([ADR 0006](docs/adr/0006-button-looks.md)): the variants are `:primary`, `:secondary`, `:plain`, `:link`, `:text`, `:soft` (the tone's light color behind its color) and `:icon` (an icon only, 24×24; give it an `aria-label`). A tone (`:success`, `:warning`, `:danger`, `:neutral`, `:highlight`) colors a primary button's background and the others' text and border; `:soft` has no look with `:neutral` or `:highlight`. `padded` (default `true`) makes a plain or text button as tall as a primary one beside it; `padded={false}` fits it to its text.
- **States the app sets** are boolean attributes: `loading`, `invalid`, `disabled`, `checked`. On a form control, `disabled` and `checked` set the element's own attribute; elsewhere a state adds its class (`prism-radio--disabled`). The browser's states (pressed, hovered, focused) need nothing.
- **Parts** follow the design's order: the label is the inner block, the icon a `<:icon>` slot (with it, the button gets `prism-button--with-icon`), and the spinner shows while `loading`. The icon goes at the start of the label, or at its end with `icon_position={:end}`; start and end follow the text's direction. Any other value warns at compile time and fails when it renders, as `as` does.
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

The props follow the same rules as the Phoenix components: axes are props typed from the design (TypeScript rejects `variant="primray"`), with the design's defaults; `padded` is a boolean prop (default `true`); a spinner's `size` is a number (`size={16}`) and `progress` a number from 0 to 100; the app's states are boolean props; parts come in the design's order (`children` is the label, `icon` adds `prism-button--with-icon` and goes at the start of the label, or at its end with `iconPosition="end"`, and any other value throws when it renders; the spinner shows while `loading`); `className` appends, and the other props and the ref go on the element. The package's README ([targets/react/README.md](targets/react/README.md)) has the details. The components are generated into `targets/react/src/` and built with `tsc` into ES modules and type declarations; React 18 and 19 work.

## Use it in a design tool

`targets/design-tools/` holds three files, generated from the design and attached to each release:

| File | What |
|---|---|
| `tokens.json` | Every token in the [W3C Design Tokens (DTCG) format 2025.10](https://www.designtokens.org/tr/2025.10/format/), with no tool-specific fields: colors, font families and weights, font sizes and line heights, typography, spacing, heights, radii, shadows and text shadows, each with its DTCG `$type`. A family is the web font (`Nunito`, `Nunito Sans`); its fallback and its iOS and Android binding (the system font) are under `$extensions.prism`. |
| `tokens.css` | The same tokens as CSS custom properties on `:root`, named by the same rule: the DTCG path `color.primary` is `--prism-color-primary`. A typography token is the `font` shorthand, a shadow the `box-shadow` (or `text-shadow`) value. The 50% radius is only here: DTCG has no percent unit. |
| `overview.svg` | Every token drawn (swatches, the fonts and typography in their own fonts, spacing, radii, shadows) and every component's variants and states, as shapes and `<text>`. It opens in a browser as it is, and has no external references. |

[ADR 0005](docs/adr/0005-design-tools.md) records the names and how typography, shadows and font roles are written. `npm test` in `targets/design-tools/` checks the files: `tokens.json` against the DTCG 2025.10 JSON Schema and through [Terrazzo](https://terrazzo.app)'s and [Style Dictionary](https://styledictionary.com)'s parsers, `tokens.css` against the same names, and `overview.svg` as standalone SVG. CI runs it.

The overview names Nunito and Nunito Sans: install them (from `targets/web/fonts/`, or [Google Fonts](https://fonts.google.com/?query=nunito)) before you import it, or its text falls back to another font.

### Import steps

Each step is checked against the tool's documentation (October 2026), not tried by hand.

**Figma** ([variables import](https://help.figma.com/hc/en-us/articles/15343816063383-Modes-for-variables), on the Professional plan or higher):

1. In the Variables view, create a collection, then drag `tokens.json` onto it. Figma makes a variable for each token it supports: colors, `px` dimensions (as numbers) and font families. It names them by path with `/` (`color/primary`).
2. Figma's import leaves out the rest: font weights, the `rem` radius, typography and shadows. For typography and shadows as Figma styles, use a plugin that reads DTCG, such as [Tokens Studio](https://docs.tokens.studio/manage-settings/token-format) in its W3C DTCG format, and check that it reads 2025.10 values (colors and dimensions as objects).
3. Drag `overview.svg` onto the canvas. Figma [turns an SVG into editable layers](https://help.figma.com/hc/en-us/articles/360040028034-Import-files-to-the-file-browser).

**Penpot** ([design tokens](https://help.penpot.app/user-guide/design-systems/design-tokens/)):

1. In the tokens panel, choose Tools, then Import, and pick `tokens.json`. A single file becomes one token set named after the file; the tokens keep their paths (`color.primary`). Colors, dimensions, font families and weights, typography and shadows are all token types Penpot has.
2. Penpot has read DTCG with values as text so far (`"#4272EF"`, `"16px"`). Its current resolver reads the 2025.10 color objects but not the dimension objects (`{"value": 16, "unit": "px"}`), so sizes, typography and shadows may show as errors; a newer resolver on Penpot's main branch reads them. Check after importing.
3. [Insert](https://help.penpot.app/user-guide/designing/layers/#images) `overview.svg` with the image tool (K), or drag it onto the viewport.

**pen.dev** ([variables](https://docs.pen.dev/core-concepts/variables)):

1. Attach `tokens.css` in the AI agent and ask it to create variables from it. pen.dev has color, number and string variables, so it takes the colors, sizes and font families; typography and shadows have no variable type there.
2. Import `overview.svg` with [Import Image or SVG](https://docs.pen.dev/core-concepts/import-and-export) (below the Rectangle tool, or File > Import); an SVG becomes editable layers.

**Paper** ([tokens](https://paper.design/docs/tokens)):

1. Connect your agent to Paper through its [MCP server](https://paper.design/docs/mcp), point it at `tokens.css`, and ask it to create Paper tokens from the CSS variables. Paper has tokens for colors, radii, spacing, font families, weights, sizes and line heights; it has none for typography or shadows yet.
2. Copy the source of `overview.svg` and [paste it](https://paper.design/docs/svg) into the file (⌘V).

**Webflow** comes later: a Designer Extension will write `tokens.json` into a site's Variables. A color, a size and a font family each have one flat value, so each maps to one Webflow variable.

## The generator

- The schema turns a design into plain data, `__schema__/0`, whose shape is documented in `Prism.Generator.Schema`. The targets read only that data, never the schema's internals; a test checks that no other file calls into the schema.
- A component's look is shared by every target. Each target's mechanics (for the web: display, cursors, focus outlines, keyframes, the check mark) are in the generator, and a value that really differs per platform is a `web:`, `ios:` or `android:` binding in the design; see ADR 0001, decision 3.
- `mix prism.gen` generates every target named in the config (today `web`, `react` and `design_tools`), puts a `Prism.Generator.Header` line on each file, and never overwrites a file that doesn't start with exactly that line. It removes a left-over file, which no target generates now (a renamed or removed component's), and `--check` fails on one. Only a regular file, not a link, of a type the targets write, in a folder a target writes into (not the folders below it), that starts with exactly the header is left over; everything else there stays, such as a `package.json` or a note that mentions the header. A later target adds a module and its templates, not a task.
- `Prism.Generator.Phoenix` is no file target: an app's module `use`s it and gets its components at compile time (ADR 0003). Phoenix LiveView is an optional dependency of the generator; CI compiles the generator without it too (`mix compile --no-optional-deps`). The web target, the Phoenix components and the React target share `Prism.Generator.Web.Classes` for class names, and the two kinds of components share `Prism.Generator.Web.Elements` for their markup.
- The generator gets the design only from the config, never by naming it. It compiles and tests on its own, without `design/`, so a reference to Prism's design fails its build. CI also checks that it mentions none of Prism's values.
- Its tests use neutral example designs: `generator/test/support/example_design.ex`, whose files they compare with reviewed fixtures in `generator/test/fixtures/`, and `example_components.ex`, one component of every kind, which they render through `Prism.Generator.Phoenix` and check against its CSS. Its React components are a fixture package too, `generator/test/fixtures/react/`, whose `npm test` type-checks them and renders them against the example's CSS (`generator/test/fixtures/example_components/`).
- **Moving it to its own repository:** move `generator/` out as it is, and change one line in `design/mix.exs` from `path: "../generator"` to a git or Hex dependency.

## Publish

Install Prism from npm. The repository root is no longer the package (it lives in `targets/web/`), so installing from git or linking to files at the root of the repository no longer works.

Publishing is manual for now: the npm packages from `targets/web/` and `targets/react/`, with the same version for both, and the design-tool files as release assets:

1. Bump the version in `design/mix.exs`, `targets/web/package.json`, and in `targets/react/package.json` both its version and its peer dependency on `@novasoftwarefoundation/prism`. Then update the React package's lockfiles: `cd targets/react && npm install --package-lock-only && ../../.github/react18.sh --update` (the second writes CI's React 18 lockfile from the bumped files, and leaves them as they are). A test checks that all of them are equal. Merge it.
2. Check the packages: `cd targets/web && npm pack --dry-run` lists the files in `.github/npm-files.txt`, and `cd targets/react && npm ci && npm pack --dry-run` (which builds `dist/`) those in `.github/npm-files-react.txt`.
3. Publish the CSS first, since the components depend on it: `cd targets/web && npm publish --access public`.
4. Then the components: `cd targets/react && npm publish --access public`.
5. Attach the design-tool files to the release, from the tag:
   1. Tag the merge `vX.Y.Z`, push the tag, and check it out: `git checkout vX.Y.Z`.
   2. Check that the tree is the tag's, with no local changes or untracked files, and that the files are the design's: `test -z "$(git status --porcelain)" && (cd design && mix prism.gen --check)`. The commands here run from the repository root.
   3. Create a GitHub release for the tag with `targets/design-tools/tokens.json`, `tokens.css` and `overview.svg` as its assets: `gh release create vX.Y.Z targets/design-tools/tokens.json targets/design-tools/tokens.css targets/design-tools/overview.svg`. If the release exists already (a rerun), upload them again instead: `gh release upload vX.Y.Z targets/design-tools/tokens.json targets/design-tools/tokens.css targets/design-tools/overview.svg --clobber`.

   There is no release automation yet.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
