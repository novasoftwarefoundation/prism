# Prism

A Tailwind-based UI framework for scientific software, published on npm as `@novasoftwarefoundation/prism`.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

To use Prism in an app, see the package's README: [targets/web/README.md](targets/web/README.md) (install, Tailwind preset, CSS, classes). A Phoenix app also gets Prism's components as function components; see [Use it in a Phoenix app](#use-it-in-a-phoenix-app). A React app gets them from `@novasoftwarefoundation/prism-react`; see [Use it in a React app](#use-it-in-a-react-app). An iOS app gets the tokens and the components in SwiftUI from the `prism-swift` package; see [Use it in a SwiftUI app](#use-it-in-a-swiftui-app). A design tool gets the tokens and an overview of the design; see [Use it in a design tool](#use-it-in-a-design-tool).

## Layout

Prism's look is written once, as a design in Elixir, and generated into code for each target: an app platform, or a design tool. The top of the repository shows the split:

| Folder | What |
|---|---|
| `design/` | Prism's design, a Mix project (`:prism_design`): `lib/tokens.ex` (`Prism.Design.Tokens`), `lib/components.ex` (`Prism.Design.Components`, which takes the tokens and is the whole design), `config/config.exs` (the design module and the folder of each target), and its checks: the 0.1.7 golden test, the version check, the font roles, the typography, the components. |
| `generator/` | The generic part, a Mix project of its own (`:prism_generator`): the design format (`lib/schema.ex`, with components in `lib/schema/components.ex`), the header of generated files (`lib/header.ex`), the web target (`lib/web.ex`, its templates in `lib/web/`, the component mechanics in `lib/web/components.ex`, the class names in `lib/web/classes.ex`, and the components' markup in `lib/web/elements.ex`), the Phoenix components (`lib/phoenix.ex`, `Prism.Generator.Phoenix`), the React target (`lib/react.ex`, `Prism.Generator.React`), the design-tool target (`lib/design_tools.ex`, `Prism.Generator.DesignTools`, with the overview in `lib/design_tools/overview.ex`), and `mix prism.gen` (`lib/mix/tasks/prism.gen.ex`). It knows nothing about Prism's values. |
| `targets/web/` | The npm package `@novasoftwarefoundation/prism`: `package.json`, the generated `tailwind.preset.js`, `css/base.css` and `css/components.css`, and `fonts/`. |
| `targets/react/` | The npm package `@novasoftwarefoundation/prism-react`: `package.json`, `tsconfig.json`, the generated components in `src/`, and their tests in `test/`. |
| `targets/swift/` | The Swift package `Prism`, released as the `prism-swift` repository: the generated `Package.swift` and `Sources/Prism/` (the tokens, the looks and one file per component), with a hand-written `README.md` and `LICENSE`. |
| `targets/design-tools/` | Files for design tools, attached to each release: the generated `tokens.json` (DTCG), `tokens.css` (CSS custom properties) and `overview.svg`, and their checks (`package.json`, `test/`). |
| `targets/webflow/` | The Webflow Designer Extension "Prism tokens", hand-written, which writes `tokens.json` into a site's variables; its bundle is attached to each release. |

`design/` depends on `generator/` with `{:prism_generator, path: "../generator"}`; there is no Mix project at the root. Decisions are in `docs/adr/`: [0001: design format](docs/adr/0001-design-format.md), [0002: Prism's design](docs/adr/0002-prism-design.md), [0003: Phoenix components at compile time](docs/adr/0003-phoenix-components.md), [0004: React components](docs/adr/0004-react-components.md), [0005: files for design tools](docs/adr/0005-design-tools.md), [0006: button looks](docs/adr/0006-button-looks.md), [0007: spinner sizes and progress](docs/adr/0007-spinner-sizes-progress.md), [0008: a state the app sets outweighs the pointer and the focus](docs/adr/0008-app-state-over-interaction.md), [0009: the Swift target](docs/adr/0009-swift-target.md), [0010: the text field's prefix](docs/adr/0010-text-field-prefix.md) and [0011: the image picker](docs/adr/0011-image-picker.md).

## Change the design

Optional per-input debounce metadata is described in
[ADR 0012](docs/adr/0012-semantic-input-metadata.md). `text_field` and `text_area`
declare `debounce_ms`: integer milliseconds 1..2147483647. Prism validates this
semantic data; the containing Form consumer submits the form once the input has
been unchanged for `debounce_ms`. With absence/null/nil the form doesn't submit
automatically: the user submits it.

```elixir
Prism.Generator.InputMetadata.validate!(
  Prism.Design.Components.__schema__(), :text_field, %{debounce_ms: 500}
)
```

React consumers import `textFieldInputMetadata({ debounceMs: 500 })`
and `TextFieldInputMetadata` from `@novasoftwarefoundation/prism-react`.
Swift consumers construct `try PrismTextFieldInputMetadata(debounceMs: 500)`
or decode that Codable type from snake_case input metadata. Text areas have the
corresponding `TextArea` APIs. These data types belong in the Form's input model;
they do not change styled field APIs or submit forms by themselves.

`targets/web/tailwind.preset.js`, `targets/web/css/base.css`, `targets/web/css/components.css`, `targets/react/src/`, the three files in `targets/design-tools/`, and `targets/swift/Package.swift` and `targets/swift/Sources/` are generated: don't edit them by hand. Change `design/lib/tokens.ex` (tokens) or `design/lib/components.ex` (components), then regenerate and commit the result. An app adjusts a component through the component's own API, never by editing a generated file.

```sh
cd design
mix deps.get
mix prism.gen   # writes every target: ../targets/web (the preset and the CSS), ../targets/react/src, ../targets/design-tools and ../targets/swift
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
     git: "https://github.com/novasoftwarefoundation/prism.git", tag: "v0.3.0", subdir: "design"},
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

<MyAppWeb.Prism.field invalid={@errors != []}>
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

- **Axes** (`variant`, `tone`, `size`, `status`, a text area's `editor`) are atom attributes with the design's values (a spinner's `size` an integer), so Phoenix warns at compile time about `variant={:primray}`, and a value it can't check then (from an assign) fails when it renders. Without one, an axis has the design's default: a button's tone is accent and a spinner's size 24 (no class), a tag's tone is `:accent`, a message bar's `:info`, a step's `:incomplete`. A button's `variant` and a spinner's color have no default. A text area's `editor` is `:plain`, or `:rich_text` (16px on every side) for the box around the app's rich-text editor. A text area with `editor={:rich_text}` is a `<div>` with the text area's classes around its inner block, the app's rich-text editor: its toolbar goes inside the box, and its editing surface takes the class `prism-text-area__editor` (`<trix-editor class="prism-text-area__editor">`); `disabled` on that surface disables the box. The wrapper takes its own attributes only: `disabled`, `value` and the textarea's own attributes (`rows`, `placeholder`, `name`, …) fail when it renders, since they are the editor's; a plain text area fails on an inner block, since its content is its `value`.
- **Spinners** ([ADR 0007](docs/adr/0007-spinner-sizes-progress.md)): `size` is an integer, the spinner's px: `16`, `20`, `24` (the default) or `32` (`size={16}`). `progress`, a number from 0 to 100 or `nil`, shows a light grey ring (white at 20% on the inverse spinner) with an arc in the spinner's color as long as the value (clamped to 0..100), with `role="progressbar"` and the ARIA values; the spinner keeps turning. Name it with `aria-label` (or `aria-labelledby`): `<MyAppWeb.Prism.spinner progress={@upload.progress} aria-label="Uploading" />`. A loading button's spinner is 20px.
- **Buttons** ([ADR 0006](docs/adr/0006-button-looks.md)): the variants are `:primary`, `:secondary`, `:plain`, `:link`, `:text`, `:soft` (the tone's light color behind its color) and `:icon` (an icon only, 24×24; give it an `aria-label`). A tone (`:success`, `:warning`, `:danger`, `:neutral`, `:highlight`) colors a primary button's background and the others' text and border; `:soft` has no look with `:neutral` or `:highlight`. `padded` (default `true`) makes a plain or text button as tall as a primary one beside it; `padded={false}` fits it to its text.
- **States the app sets** are boolean attributes: `loading`, `invalid`, `disabled`, `checked`. On a form control, `disabled` and `checked` set the element's own attribute; elsewhere a state adds its class (`prism-radio--disabled`). The browser's states (pressed, hovered, focused) need nothing.
- **Parts** follow the design's order: the label is the inner block, the icon a `<:icon>` slot (with it, the button gets `prism-button--with-icon`), and the spinner shows while `loading`. The icon goes at the start of the label, or at its end with `icon_position={:end}`; start and end follow the text's direction. Any other value warns at compile time and fails when it renders, as `as` does. A text field takes a `<:prefix>` before its text, a currency symbol or the app's own picker ([ADR 0010](docs/adr/0010-text-field-prefix.md)): it is then a `<div>` with the text field's classes around the prefix and the `<input>`, which gets the other attributes (`name`, `phx-*`) and `disabled`. Adding or removing the prefix on a field that is on screen swaps its element, so the input loses its focus: give a field that may get a prefix one from its first render.
- **Image pickers** ([ADR 0011](docs/adr/0011-image-picker.md)): `shape` is `:rectangular` (the default) or `:round`. The app puts its image (or its placeholder) in `<:preview>` and its own button in `<:button>`, with the variant it picks: primary while there is no image, secondary with one. The file input is the app's: keep it focusable and visually hidden (`sr-only`, not `hidden`), so a keyboard reaches the picker, and give it the focus style you want.

  ```heex
  <MyAppWeb.Prism.image_picker shape={:round}>
    <:preview><img src={@photo_url || ~p"/images/placeholder.svg"} alt="" /></:preview>
    <:button>
      <label>
        <MyAppWeb.Prism.button as="span" variant={if @photo_url, do: :secondary, else: :primary}>
          Choose
        </MyAppWeb.Prism.button>
        <.live_file_input upload={@uploads.photo} class="sr-only" />
      </label>
    </:button>
  </MyAppWeb.Prism.image_picker>
  ```
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

<Field label="Email" labelProps={{ htmlFor: "email" }} errorMessage={errors[0]} invalid={errors.length > 0}>
  <TextField id="email" name="email" invalid={errors.length > 0} />
</Field>

<Tag tone="success">Done</Tag>
```

The props follow the same rules as the Phoenix components: axes are props typed from the design (TypeScript rejects `variant="primray"`, and from untyped JavaScript any other value throws when it renders), with the design's defaults; `padded` is a boolean prop (default `true`); a spinner's `size` is a number (`size={16}`) and `progress` a number from 0 to 100 (anything else that isn't a number throws when it renders); the app's states are boolean props; parts come in the design's order (`children` is the label, `icon` adds `prism-button--with-icon` and goes at the start of the label, or at its end with `iconPosition="end"`, and any other value throws when it renders; the spinner shows while `loading`); `className` appends, and the other props and the ref go on the element. The package's README ([targets/react/README.md](targets/react/README.md)) has the details. The components are generated into `targets/react/src/` and built with `tsc` into ES modules and type declarations; React 18 and 19 work.

## Use it in a SwiftUI app

An iOS app (iOS 26 or later) depends on the Swift package `Prism`, from the `prism-swift` repository at Prism's version:

```swift
.package(url: "https://github.com/novasoftwarefoundation/prism-swift.git", exact: "0.3.0")
```

```swift
import Prism

Button("Save", action: save)
    .buttonStyle(.prism(.primary, tone: .danger, loading: saving))

PrismField(focused: emailFocused, invalid: error != nil, label: Text("Email"), errorMessage: error.map(Text.init)) {
    TextField("", text: $email)
        .focused($emailFocused)
        .prismTextField(focused: emailFocused, invalid: error != nil)
}

ProgressView(value: 0.4).progressViewStyle(.prism(.accent, size: .size32))
PrismTag(tone: .success) { Text("Done") }
```

Each component takes SwiftUI's own form ([ADR 0009](docs/adr/0009-swift-target.md)): a `ButtonStyle` for the button, a `ProgressViewStyle` for the spinner, a `ToggleStyle` for the checkbox, a modifier for the text field and the text area, and a view for the others. Axes are enums of the design's values (`.primary`, `.danger`, `.size32`) with the design's defaults; flags and the states the app sets are parameters; pressed, disabled and checked come from SwiftUI. A component's looks are data too (`PrismButtonLooks`), laid over each other as the web's CSS does. A look animates and a move in the same update doesn't, except a button's: put `.geometryGroup()` on a Prism button whose place can change. Type follows Dynamic Type. The package's README ([targets/swift/README.md](targets/swift/README.md)) has the details. The package is generated into `targets/swift/`; CI builds it with `xcodebuild` for the iOS Simulator.

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

**Webflow** ([ADR 0014](docs/adr/0014-webflow-designer-extension.md)): the Designer Extension "Prism tokens" writes `tokens.json` into a site's variables with one click. It updates the site's variables by name and adds the missing ones to the same collection; typography and shadows have no Webflow variable and are skipped. Each release attaches it as `prism-tokens-webflow.zip`; [targets/webflow/README.md](targets/webflow/README.md) says how to install it in a workspace and apply a release. `npm test` in `targets/webflow/` runs it against a fake of the Designer API, and CI runs it and builds the bundle.

## The generator

- The schema turns a design into plain data, `__schema__/0`, whose shape is documented in `Prism.Generator.Schema`. The targets read only that data, never the schema's internals; a test checks that no other file calls into the schema.
- A component's look is shared by every target. Each target's mechanics (for the web: display, cursors, focus outlines, keyframes, the check mark) are in the generator, and a value that really differs per platform is a `web:`, `ios:` or `android:` binding in the design; see ADR 0001, decision 3.
- `mix prism.gen` generates every target named in the config (today `web`, `react`, `design_tools` and `swift`), puts a `Prism.Generator.Header` line on each file, and never overwrites a file that doesn't start with exactly that line. It removes a left-over file, which no target generates now (a renamed or removed component's), and `--check` fails on one. Only a regular file, not a link, of a type the targets write, in a folder a target writes into (not the folders below it), that starts with exactly the header is left over; everything else there stays, such as a `package.json` or a note that mentions the header. A target may also copy a file (the Swift package's fonts, when the design binds iOS to named fonts): a copy has no header and is written byte for byte, and `--check` compares its bytes. In a folder a target copies into (it names them, also while it copies nothing), any file that no target copies now is left over too, and a linked copy folder fails the task. A later target adds a module and its templates, not a task.
- `Prism.Generator.Phoenix` is no file target: an app's module `use`s it and gets its components at compile time (ADR 0003). Phoenix LiveView is an optional dependency of the generator; CI compiles the generator without it too (`mix compile --no-optional-deps`). The web target, the Phoenix components and the React target share `Prism.Generator.Web.Classes` for class names, and the two kinds of components share `Prism.Generator.Web.Elements` for their markup.
- The generator gets the design only from the config, never by naming it. It compiles and tests on its own, without `design/`, so a reference to Prism's design fails its build. CI also checks that it mentions none of Prism's values.
- Its tests use neutral example designs: `generator/test/support/example_design.ex`, whose files they compare with reviewed fixtures in `generator/test/fixtures/`, and `example_components.ex`, one component of every kind, which they render through `Prism.Generator.Phoenix` and check against its CSS. Its React components are a fixture package too, `generator/test/fixtures/react/`, whose `npm test` type-checks them and renders them against the example's CSS (`generator/test/fixtures/example_components/`). Its Swift packages are fixtures as well, `generator/test/fixtures/swift/components/` and `…/design/`, which CI builds with `xcodebuild`.
- Its `mix test` needs Node (`nodejs` in `.tool-versions`): a test loads the generated preset in plain Node.
- **Moving it to its own repository:** move `generator/` out as it is, and change one line in `design/mix.exs` from `path: "../generator"` to a git or Hex dependency.

## Swift validation in CI

Swift builds and simulator tests run when their tested inputs or environment have no matching successful validation record. CI always runs the generator tests and checks generated files first. Thus a design/generator change that changes Swift must update the committed package or fixtures; stale output cannot use a prior Swift pass. A design change with identical Swift output needs no second simulator run.

The fingerprint covers all tracked files in `targets/swift/` (except its README, license and gitignore), `generator/test/fixtures/swift/`, and `design/test/swiftui/`, plus the tool versions, CI/release workflows and validation scripts/tests. Added/deleted files count too. Runner image/OS/architecture, exact Xcode build, Node version, simulator runtime build and selected iPhone type also belong to the fingerprint. Version metadata, web/React-only changes and documentation outside those inputs leave it unchanged.

A matching record can be reused across an internal PR, branch promotion and release tag. CI verifies the artifact digest and its full input/environment manifest, the same repository and CI/release workflow paths, the original successful run/attempt, and that the original Swift build/render steps actually ran and passed. Fork evidence and records from skipped, failed, in-progress or unrelated runs are refused. A reused job links the original run in its summary and does not issue a new test record. This keeps the evidence tied to the run that actually executed the suite.

Records are retained for 30 days. Missing, expired, corrupt or inaccessible evidence runs the full suite; lookup problems never count as a pass. The macOS job still selects/identifies its environment on a cache hit, but skips the expensive builds and simulator tests. A changed environment or validation implementation requires a new full run.

## Publish

Install Prism from npm. The repository root is no longer the package (it lives in `targets/web/`), so installing from git or linking to files at the root of the repository no longer works.

Releases are started by pushing a version tag after the release commit reaches `main`:

```sh
git tag -a vX.Y.Z -m "Prism vX.Y.Z"
git push origin vX.Y.Z
```

Before tagging, bump the version in `design/mix.exs`, `targets/web/package.json`, and both the version and Prism peer dependency in `targets/react/package.json`. Update React's lockfiles with `cd targets/react && npm install --package-lock-only && ../../.github/react18.sh --update`, then regenerate and commit the design output. Follow the normal `spec` → `develop` → `main` review and merge flow before tagging.

`.github/workflows/release.yml` runs the full CI suite at the tag. It requires the tagged commit to be on `main`, checks all versions, verifies generated output and both npm package file lists, then:

1. Publishes `targets/web/` and `targets/react/`, in that order. It waits for npm's processing to finish and verifies package hashes. npm trusted publishing provides authentication.
2. Mirrors the tag's tracked `targets/swift/` files into `prism-swift` using `.github/swift-release.sh`, committing and pushing the branch and tag atomically.
3. Creates the GitHub release and attaches `tokens.json`, `tokens.css`, `overview.svg` and the Webflow Designer Extension's bundle, `prism-tokens-webflow.zip`. A job of its own, which can only read, builds that zip before step 1; the publishing job takes it as an artifact and checks its file list, so Webflow's CLI never runs where npm and the Swift deploy key can be used.

Stable tags use `vX.Y.Z` and npm's `latest` dist-tag. Release candidates use `vX.Y.Z-rc.N`, npm's `next` dist-tag and a GitHub prerelease. Candidates do not move `latest`.

### One-time release setup

- On each npm package (`@novasoftwarefoundation/prism` and `@novasoftwarefoundation/prism-react`), configure GitHub Actions trusted publishing: owner `novasoftwarefoundation`, repository `prism`, workflow filename `release.yml`, no environment restriction. Enable publishing for that trusted publisher. The job uses `id-token: write`; no npm token secret is needed. The pinned Node version includes a compatible npm CLI (11.5.1 or later).
- Create a write-enabled deploy key on `novasoftwarefoundation/prism-swift` only. Store its private half in the `novasoftwarefoundation/prism` Actions secret `PRISM_SWIFT_DEPLOY_KEY`. The workflow pins the SSH host keys from GitHub's HTTPS metadata API and removes the temporary private key when the step ends.
- GitHub's workflow token creates the Prism release/assets with `contents: write`.

### Failed or partial releases

Check the failed step before rerunning the workflow. Published npm versions are reused only when their hashes match the prepared packages. An existing Swift tag must contain exactly the expected tracked files and belong to its main branch. Existing GitHub releases receive the tag's design assets again. Nothing moves or deletes a published version tag. If npm accepted an upload but is still processing it, wait for processing to finish before rerunning; do not submit another upload manually. Fix incorrect published content in a new patch version.

The local release checks can be run without publishing:

```sh
node --test .github/release-version.test.mjs .github/release-publish.test.mjs .github/release-workflow.test.mjs
# After npm ci in targets/react; choose an existing directory outside the checkout:
RELEASE_TAG=vX.Y.Z RUNNER_TEMP=/path/to/temp node .github/release-prepare.mjs
```

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
