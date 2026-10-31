# 0001: Design format: an Elixir DSL for tokens and components, generated per target

Status: proposed, 2026-10-31

## Context

A design system that ships to the web and to native apps needs the same values on every platform. When each platform copies them by hand, they drift, and component code drifts from the system's own tokens.

The fix is one design with a generator per target, and the generated code committed so every change is reviewable. There are three layers:

- **The generator** (`generator/`, a Mix project of its own) is generic: the schema a design is written in, and the generators. It knows nothing about any particular design.
- **The design** (`design/`, a Mix project that depends on the generator) is the input: a module written in the schema's DSL.
- **Targets** (`targets/<target>/`) are what the generators produce, one folder per target, published or imported from there. A target is anything a generator generates for: an app platform (`targets/web/`, later `targets/swift/`), or a design tool (later, for example a DTCG tokens file, CSS variables or an SVG overview in `targets/design-tools/`).

The design and the generators meet only at the schema's public data, `__schema__/0`: a contract that either side can rely on.

## Decision

The format has these parts:

| Layer | What | Where |
|---|---|---|
| Schema | The DSL and its rules: what a valid design is | the generator: `Prism.Generator.Schema` |
| Tokens | Colors, shadows, text shadows, spacing, sizes, radii, font families and faces, font styles, text sizes, and type styles (`typography`) built from a font style and a text size | the design: a module that uses `Prism.Generator.Schema` (`__schema__/0` returns it as data) |
| Components | Components with a base style, parts, variants and states, built from tokens, with per-target bindings | the design: the tokens' module, or a module that takes its tokens from it (`use Prism.Generator.Schema, tokens: Tokens`) |
| Generators | Web (Tailwind preset and CSS), Swift, later Kotlin | the generator: `Prism.Generator.*` and `mix prism.gen.<target>` |
| Targets | What the generators produce | `targets/<target>/`, where each one is published or imported from |

Today the generator has the schema (tokens, type styles and components) and the web generator for `tailwind.preset.js`, `css/base.css` and `css/components.css`.

1. **Tokens are declared, not computed.**

   ```elixir
   group "Brand colors" do
     color :accent, "#1A73E8"
   end
   color :link, :accent                       # alias: same value, its own name
   shadow :card, y: 5, blur: 20, color: {:black, 0.1}
   shadow :raised, :card, deprecated: true
   font :button, :text, 700                   # web: font-button
   text :button, 18, 18                       # web: text-button
   radius :default, {0.25, :rem}
   ```

   Font styles (family and weight) and text sizes (size and line height) are two lists of primitives, because a Tailwind preset has two key sets for `font-…` and `text-…`, and a design system may name them differently.

   A type style is therefore an explicit composite token, `typography`, that references one `font` and one `text` entry:

   ```elixir
   typography :title1, font: :title1, text: :title1
   ```

   Both references are required. The schema checks that each one names an entry of its own list (`font:` a font, `text:` a text size) declared before the type style. Native generators read only the `typography` tokens for type, never the two lists, so no platform pairs a font with a size on its own. The web target doesn't read them: its `font-…` and `text-…` classes stay as they are, so the web files don't change.

2. **Fonts per platform.** A family is a role that each platform binds to a font. Fonts refer to the role, so `font :title1, :display, 800` stays platform-neutral:

   ```elixir
   family :display,
     doc: "Headings (> 20px)",
     web: [name: "Acme Sans", fallback: "sans-serif", faces: [...]],
     ios: :system,
     android: :system
   ```

   - Every family must name `web`, `ios` and `android`, so adding a platform forces a choice. A binding is `:system` or a named font with its faces, for a brand font.
   - `:system` is SF Pro on iOS (`Font.system`, which picks the Display or Text optical size itself and supports Dynamic Type) and Roboto on Android (`FontFamily.Default`). The web has no `:system` binding yet.
   - Weights, italic, sizes and line heights are shared by all platforms. Sizes are px on the web, pt on iOS and sp on Android.
   - Each generator reads only its own platform's binding. The web target reads `web:`; the family names don't appear in it.

3. **Components: a shared look, mechanics per target, and bindings only where a value really differs** (`Prism.Generator.Schema.Components`).

   ```elixir
   component :btn, web: [section: "Buttons"] do
     style typography: :button, radius: :default, transition: {150, :ease_in_out}
     part :content
     part :spinner, component: :spinner

     variant :primary, background: :accent, foreground: :white, padding: [y: 15, x: 16] do
       state :pressed, padding: [top: 16, bottom: 14], shadow: :pressed
       state :disabled, opacity: 0.5
     end

     state :loading do
       part :content, opacity: 0
     end

     variants :color do
       variant :danger, background: :error, foreground: :white, aliases: [:delete]
     end
   end
   ```

   A component is one concept (a button, an input, a checkbox): its look, and how a state changes it. What it does is never part of a design. A component has four layers:

   1. **The shared look**, which every target reads. `style` is the component's own look. A `variant` is a look to choose: variants outside a `variants` block are the `:variant` axis, a `variants :color` block is a second axis that combines with the first, and `aliases:` gives a variant more names. A `part` is a named piece, in the design's order; `component:` makes it another component. A `state` changes the look while it holds. A variant or a state changes a part by naming it again.
      - States have a fixed meaning that every target knows: `:pressed`, `:hovered`, `:focused`, `:disabled`, `:checked`, `:selected`, `:loading`, `:error`.
      - Properties are a fixed, typed list: `background`, `foreground` and `placeholder` (colors); `border` and `outline` (`[width:, color:]`, plus `offset:` for the outline; a state may give only some); `radius`; `padding`, `margin` and `inset` (sides: `top`, `right`, `bottom`, `left`, `x` for left and right, `y` for top and bottom); `gap`, `size`, `height`, `min_height` and `max_height`; `typography`; `weight`; `decoration`; `shadow`; `opacity`; `transition` and `rotation` (`{milliseconds, easing}`).
      - A value is a token reference or a literal of the property's type. Colors are a color's name, `{color, alpha}`, `"#RRGGBB"` or `:transparent` (so no color token may be named `:transparent`). Lengths are px (points on iOS, dp on Android), `{n, :rem}` or `{n, :percent}`; a radius or a maximum height may also name its token. A `typography` is a typography token, or `[font: font, text: text | {size, line_height}]` for a pairing no type style has. A shadow is always a token. Durations, opacities, weights and the other lengths are literals, because the format has no tokens for them.
   2. **Platform mechanics are not design.** Display and layout, cursors, focus rings, appearance resets, keyframes, the spinner's tint filter and the checkbox's check mark image on the web (later ripple on Android, haptics on iOS) live in the target's module in `generator/`. For the web that is `Prism.Generator.Web.Components`: it knows each component by name, as a platform library does, and writes every variant, part and state the design gives it. A design component that a target doesn't know fails that target's generation.
   3. **A value that really differs per platform** gets a namespaced binding in the design, `web:`, `ios:` or `android:`, the way `family` binds a font per platform. A binding holds properties, whose values replace the shared ones on that target only, and keys of the target's own: the web's are `section:` and `doc:` (the comments of its file) and `filter:` (a spinner variant's tint filter, made for one color). A target reads only its own binding and falls back to the shared value. The schema refuses a key a target doesn't know, at compile time on the line, and a target fails when a value or key of the design is written nowhere, so nothing is silently ignored. The native targets don't exist yet, so `ios:` and `android:` take only properties for now.
   4. **Apps adjust a component through its own API**: an extra class or attributes in Elixir (`Prism.Generator.Phoenix`, later), modifiers in Swift. Never by editing generated files.

   This is the split of Material 3's component tokens (one set of values for every platform, the mechanics in each platform's library), of Style Dictionary (a platform-neutral source, with a transform and a format per platform) and of the Design Tokens Community Group format's `$extensions` (tool-specific data under its own namespace).

   On the web a class is made of the design's names: `.<prefix>-<component>`, then `-<variant>`, `-<part>` or `-<state>`, with `-` for `_`. Renaming a design name renames its class; there is no binding for class names.

4. **The design names its web files.** A `web` declaration gives the class prefix (`prefix: "acme"` gives `.acme-text-shadow`), where the CSS finds the font files, how many line-clamp classes to write, and the comments at the top of each file (`components_doc:` for `css/components.css`). The templates hold no names of their own, so the same generator serves any design.

5. **Mistakes fail at compile time and point at their line:**
   - an unknown option, property or token kind;
   - a name that isn't a snake_case atom;
   - a duplicate, or a `web` declaration given twice;
   - a value of the wrong type (a lower-case hex color, a font weight that isn't one of 100, 200, …, 1000, face weights outside 1..1000, a negative size or blur);
   - text that can't be written safely into the generated JavaScript and CSS: a quote, a backslash, a line break or `*/` in a group or doc, and anything but letters, digits, spaces, `_` and `-` in a font name or fallback;
   - a nested `group`;
   - a family that doesn't bind `web`, `ios` and `android`, or binds one to something other than `:system` or a named font with faces;
   - a reference to a missing token, or one of the wrong kind;
   - a node in the wrong place: a `state` outside a component, a part inside a part, a token or a `group` inside a component, a component inside a `group`;
   - an unknown property, state or binding key; an option named like a node's own fields (`name:`, `kind:`, `group:`, `line:`) is refused as an unknown option;
   - two variants, aliases, parts or states of a component with one name, a change to a part the component doesn't declare, or a `component:` that isn't another component.

6. **Naming:**
   - Design names are snake_case atoms.
   - Web keys replace `_` with `-` (`btn_pressed` → `btn-pressed`).
   - Swift uses camelCase (`Shadows.btnPressed`) and escapes keywords.

7. **Targets read `__schema__/0`, never the source or the schema's internals.** The data it returns is documented in `Prism.Generator.Schema`. Each target is a module with `files/1`, from that data to `[{path, body, design_file}]`, plus its templates; `design_file` is the design file the body is made from. One task, `mix prism.gen [--check]`, generates every target named in the design project's config (`config :prism_generator, design: MyApp.Design, targets: [web: "../targets/web"]`); it never names a design itself. It writes each file with `Mix.Generator.create_file/3`, starting with a `Prism.Generator.Header` line: `Generated by prism (mix prism.gen). Do not edit: change <design file> and regenerate.`, where the design file is the one the file is made from (the tokens' file for the preset and the base CSS, the components' file for the component CSS), named from the folder that holds both it and the target. It never overwrites a file without that line, and `--check` writes nothing and fails when any file would change. A new target adds a module and templates, not a task.
   - Web (`Prism.Generator.Web`): EEx templates named after the files they produce (`generator/lib/web/tailwind.preset.js.eex`, `base.css.eex`) that splice in the design's values, and `Prism.Generator.Web.Components` for `css/components.css`, with each component's mechanics. Its spelling is fixed, so regenerating gives the same bytes: upper-case hex and two-decimal alphas in the preset, lower-case hex and `rgba()` in the component CSS, `0` in box shadows (`0px` in the dropdown's list), `0px` in text shadows, and `@font-face` sources and a spinner's filter wrapped at 80 columns.
   - Swift (later): one file with value types, the tokens, and one resolved style per component, part, variant and state, with the `ios:` bindings applied. Type comes from the `typography` tokens and the components' typography pairs, never from the font and text lists alone. Values only; views stay hand-written.
   - Kotlin (later): the same values for Compose.

8. **The generated files are committed** in `targets/<target>/`. CI regenerates them and fails when they differ from what is committed, so reviewers see every change to them. The generator compiles and tests on its own, without the design, so the compiler refuses any reference from the generator to a design; CI also checks that it mentions none of the design's values.

## Alternatives

| Option | Why not |
|---|---|
| Style Dictionary / W3C design-token JSON | The standard for tokens, but it has no components with variants and states, needs a Node toolchain next to Elixir, and generators would fight its transforms to reproduce an existing package byte for byte. A later generator can export design-token JSON from `__schema__/0` for tools that need it. |
| Keep the CSS as the source and parse it for native platforms | It makes the CSS mechanics the contract, and there is still no place for the values the CSS hard-codes. |
| Tokens only, components hand-written per platform | That is the drift this format removes. Components are where platforms most need the same numbers. |
| A data file (`.exs` maps) instead of macros | Simpler, but no compile-time errors with line numbers. |
| Schema, generators and the design in one Mix project | Simpler at first, but the split is then only a convention plus a CI script, the generic part grows assumptions about the design, and it can't be built on its own. Two sibling Mix projects, with the design depending on the generator by path, let the compiler enforce the split. |
| An umbrella project | More structure than two projects need, and not the usual way to keep a framework and one of its users in one repository; sibling projects with a path dependency are. |

## Consequences

- One language and one review for every platform's styling. Native apps get the same numbers as the web by construction.
- Editing the look means editing Elixir and running the generators. A docs generator can later turn a design into token tables.
- The web templates still look like CSS and JavaScript, and the component mechanics read as CSS declarations in `Prism.Generator.Web.Components`. Reviewers see web mechanics there and design values in the design.
- A target knows its components by name, as a platform library does. A new kind of component needs its mechanics in each target; a new variant, part or state of a known component needs only the design.
- The generator can move to its own repository without changes to its code: move `generator/` and change the design's one dependency line from `path:` to git or Hex.
