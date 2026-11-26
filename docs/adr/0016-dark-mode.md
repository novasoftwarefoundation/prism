# 0016: Dark mode

Status: proposed, 2026-11-26

## Context

Prism has one palette. Every color token has one value, and every target writes it as a constant: the web's component CSS writes hex (`background-color: #4272ef`), the Swift package `Prism.Colors.primary = Color(prismHex: 0x4272EF)`, the Kotlin library a `val` in an `object`. No target follows the system's light or dark setting. Where a component leaves a color to the platform, the platform's dark color shows through: on macOS in dark mode the select's chevron takes the system's primary color and turns white on the select's white field (Flux 10550924645).

Five components have an `inverse` variant "on a dark background": the text field, the text area, the field and the select change only their focus color (`tertiary` for `primary`), and the spinner is white. The field itself stays white. No consumer we can read uses an `inverse` class or variant.

Melle asked for dark mode on 26 November (Flux 10551091173): every token that carries a color has a light and a dark value in the design source, and each target follows it the way that platform expects.

What the code shows:

- **A token plays two roles.** `white` is the background of the fields, the select's list and the tag, and also the text and marks on a colored fill: the primary button's label, a tone's primary button, the checked checkbox's check mark, the current and complete step's number, the inverse spinner. In dark mode the first must turn dark and the second must stay readable on the fill. `grey1` is text almost everywhere, but also the text on the yellow highlight button, which must stay dark in both modes. One dark value per token can't serve both roles.
- **The greys are used by step, not by hue.** `grey1` is text, `grey2` the placeholder and muted text, `grey3` borders and disabled text, `grey4` to `grey6` quiet backgrounds (a track, a disabled field, a hovered option, the prefix). Each step keeps its role in dark mode if the scale turns over.
- **The look is shared, the colors are references.** The Swift and Kotlin looks name tokens (`Prism.Colors.grey3`), never hex, so a token that resolves per mode changes every component without per-mode code. The web's component CSS resolves the hex at generation time, so it has to refer to custom properties instead. Two colors are literals: the neutral tag's `"#666666"`, and the check mark, which the web bakes into an image (`fill='white'`).
- **Light mode already misses WCAG's contrast in places** (proposal, below): white on the primary button is 4.30:1, white on the success and warning buttons 2.50 and 2.44, `grey2` placeholders 2.85, `grey3` borders 1.61. A contrast check that holds both modes to WCAG would fail today in light.

No dark palette exists anywhere we can read. The design source has none; the repository has no design-tool files with modes (`tokens.json` and `overview.svg` are generated from the design); eyra.co's CSS has no `prefers-color-scheme` and no dark variables. It does have dark sections: `grey1` (#222222) backgrounds with white text and `tertiary` links (`.link-on-dark`), which is Prism's `inverse` idea, and the starting point of the proposal below.

## Decision

1. **One token, two values.** A color token gets its dark value next to its light one, on the same line:

   ```elixir
   color :primary, "#4272EF", dark: "#9DB8F9"
   color :white, "#FFFFFF", dark: :same       # the same color in both modes
   color :delete, :error                      # an alias takes both of its color's values
   ```

   - **`dark:`** is `"#RRGGBB"`, or `:same` for a color that doesn't change. An alias has no `dark:` of its own: it takes both values of the color it names.
   - **A design is light-only or has both modes.** A design without any `dark:` is light-only, and every target writes what it writes today, so the generator's example designs and their fixtures stay as they are. Once one color has a `dark:`, every other color that isn't an alias must have one too: the schema refuses a missing one at compile time, on its line ("give the color a dark value, or `dark: :same`"). So no token falls back to its light value without someone writing so.
   - **A color with alpha follows its color.** `{:primary, 0.2}` is the primary color at 20% in either mode; a shadow's `{:black, 0.1}` likewise. Every token that carries a color (colors, shadows, text shadows) therefore has a value per mode.
   - **No literal colors in a design with both modes.** A component's `"#666666"` has no dark value, so the schema refuses a literal hex there; the color becomes a token. `:transparent` stays.
   - **One token, one role.** Where a token plays two roles (see Context), the design splits it. The light values don't change, so the light look doesn't either:

     | New token | Light | Takes the place of | For |
     |---|---|---|---|
     | `background` | `#FFFFFF` | none | the page; what a component without a background of its own sits on (the contrast check, decision 6) |
     | `surface` | `#FFFFFF` | `white` | the fields', the select list's and the tag's background |
     | `oncolor` | `#FFFFFF` | `white` | text and marks on a tone's fill: the primary button (every tone but highlight), the check mark, the step's number, the spinner on a fill |
     | `ontertiary` | `#222222`, `dark: :same` | `grey1` | the text of the highlight primary button, on yellow in both modes |
     | `neutraltext` | `#666666` | the literal | the neutral tag's text |

     `white` and `black` keep their names and become `dark: :same`: white is white. The greys turn over, each step keeping its role. The neutral primary button keeps `grey1` behind `oncolor`, which in dark mode is a light button with dark text.

   - **Components never name a mode.** A look refers to tokens as today; each target resolves a token to its value in the mode the component is drawn in. There is no `dark` state, variant or binding.

   Each target gets the same rule in its own form: CSS custom properties, a dynamic color, a color scheme. The design writes the pair once.

2. **Where the dark values come from: a proposal, derived from the current palette.** It is Melle's to accept, change or replace (question 1 in the pull request); it is not a decision of this ADR. The derivation:

   - The page is `grey1`'s light value, `#222222`, the color of eyra.co's dark sections. Fields and the select's list are one step lighter (`#2B2B2B`), as dark themes raise a surface instead of shading it.
   - The greys turn over: `grey1` is the light text, `grey6` the step closest to the surface, and each step's role (text, placeholder, border, quiet background) keeps at least WCAG's ratio against what it sits on.
   - Each tone keeps its hue and is lightened until its text on the page and on its own 20% tag fill reaches 4.5:1. Text on a fill (`oncolor`) turns dark in dark mode, so a filled button is a light tone with dark text, as Material 3's dark scheme has it (question 2). `tertiary` doesn't change: it is 10.87:1 on `#222222` already.
   - The light tone colors (`primarylight`, …), the backgrounds of the soft button, become dark tints of their tone.

   | Token | Light | Dark (proposal) |
   |---|---|---|
   | `background` (new) | `#FFFFFF` | `#222222` |
   | `surface` (new) | `#FFFFFF` | `#2B2B2B` |
   | `oncolor` (new) | `#FFFFFF` | `#222222` |
   | `ontertiary` (new) | `#222222` | same |
   | `neutraltext` (new) | `#666666` | `#B8B8B8` |
   | `primary` | `#4272EF` | `#9DB8F9` |
   | `primarylight` | `#E3EAFD` | `#2A3550` |
   | `secondary` | `#FF5E5E` | `#FF7A7A` |
   | `tertiary` | `#FFCF60` | same |
   | `success` | `#52BA12` | `#6CCB3A` |
   | `successlight` | `#EBFFDF` | `#22361A` |
   | `warning` | `#F28D15` | `#F7A447` |
   | `warninglight` | `#FFEFDC` | `#3D2C17` |
   | `error` | `#DB1E1E` | `#FB9E9E` |
   | `errorlight` | `#FFECEC` | `#43201F` |
   | `delete`, `deletelight` | aliases | aliases |
   | `black`, `white` | `#000000`, `#FFFFFF` | same |
   | `grey1` | `#222222` | `#F6F6F6` |
   | `grey2` | `#999999` | `#ADADAD` |
   | `grey3` | `#CCCCCC` | `#7A7A7A` |
   | `grey4` | `#EEEEEE` | `#3D3D3D` |
   | `grey5` | `#F6F6F6` | `#353535` |
   | `grey6` | `#FAFAFA` | `#303030` |

   Every pair the components draw, in dark mode, with WCAG 2.2's contrast ratio. Text needs 4.5:1; large text (24px, or 18.66px bold) and the parts of a control (a border, a focus line, a mark) 3:1. A fill at alpha is composited over what it sits on.

   | Pair | Foreground on background | Ratio | Needs |
   |---|---|---|---|
   | Text on the page (labels, plain buttons) | `#F6F6F6` on `#222222` | 14.72 | 4.5 |
   | Text in a field | `#F6F6F6` on `#2B2B2B` | 13.10 | 4.5 |
   | Placeholder | `#ADADAD` on `#2B2B2B` | 6.31 | 4.5 |
   | Field and control border | `#7A7A7A` on `#2B2B2B` | 3.30 | 3 |
   | Field border against the page | `#7A7A7A` on `#222222` | 3.71 | 3 |
   | Prefix text | `#F6F6F6` on `#303030` | 12.21 | 4.5 |
   | Hovered option | `#F6F6F6` on `#353535` | 11.35 | 4.5 |
   | Primary text, link, secondary border, focus border, checked radio | `#9DB8F9` on `#222222` / `#2B2B2B` | 8.07 / 7.19 | 4.5 |
   | Primary button | `#222222` on `#9DB8F9` | 8.07 | 4.5 |
   | Success text / success button | `#6CCB3A` and `#222222` | 7.76 | 4.5 |
   | Warning text / warning button | `#F7A447` and `#222222` | 7.85 | 4.5 |
   | Invalid border, error message | `#F7A447` on `#2B2B2B` / `#222222` | 6.98 / 7.85 | 3 / 4.5 |
   | Danger text / danger button | `#FB9E9E` and `#222222` | 7.94 | 4.5 |
   | Neutral primary button | `#222222` on `#F6F6F6` | 14.72 | 4.5 |
   | Highlight text / highlight button | `#FFCF60` and `#222222` | 10.87 | 4.5 |
   | Soft buttons (accent, success, warning, danger) | tone on its light tone | 6.18, 6.36, 6.59, 7.16 | 4.5 |
   | Tags (accent, success, warning, danger) | tone on its 20% fill over `#2B2B2B` | 4.71, 4.63, 4.66, 4.67 | 4.5 |
   | Neutral tag | `#B8B8B8` on `grey2` at 20% over `#2B2B2B` | 4.83 | 4.5 |
   | Message bars (info, success, warning, danger) | tone on its 15% fill over `#222222` | 5.95, 5.80, 5.79, 5.83 | 4.5 |
   | Incomplete step | `#ADADAD` on `#3D3D3D` | 4.84 | 4.5 |
   | Progress arc on its track | `#9DB8F9` on `#3D3D3D` | 5.51 | 3 |
   | Secondary (no component; apps) | `#FF7A7A` on `#222222` | 6.30 | 4.5 |

   Disabled looks are left out, as WCAG leaves out inactive controls. In today's light palette, 23 of the same pairs miss their ratio; question 3 in the pull request lists them.

3. **Each target in the platform's own way.**

   - **Web (CSS).** `css/base.css` declares every color token as a custom property, by the names `tokens.css` already uses ([ADR 0005](0005-design-tools.md)): the light values on `:root`, the dark values under `@media (prefers-color-scheme: dark)` on `:root:not([data-prism-color-scheme="light"])`, and on `[data-prism-color-scheme="dark"]`; the light values again on `[data-prism-color-scheme="light"]`, for a light part of a dark page. Each block also sets `color-scheme`, so the browser's own scrollbars and form controls follow. `css/components.css` refers to the properties (`background-color: var(--prism-color-primary)`) where it writes hex today, and a color with alpha is `color-mix(in srgb, var(--prism-color-primary) 20%, transparent)` where it writes `rgba()`. The check mark becomes a mask over `background-color`, as the spinner already is ([ADR 0002](0002-prism-design.md), decision 9), since an image can't read a custom property. The preset's colors refer to the same properties, in the channel form Tailwind 3's opacity modifier needs (`rgb(var(--prism-rgb-primary) / <alpha-value>)`), so an app's `bg-primary` and `bg-primary/20` follow the mode; the preset's `darkMode` follows the same media query and attribute, so an app's own `dark:` utilities switch with Prism.
   - **Phoenix components.** Nothing per component: they write classes, and the CSS holds the colors. An app sets the attribute in its root layout (`<html data-prism-color-scheme={@color_scheme}>`), or on any element for a part of the page.
   - **React.** The same: the attribute on the app's root element, or on any element. No provider and no context: the CSS does the work, so server rendering and the first paint are already in the right mode.
   - **Swift.** A color token is a dynamic color: `Prism.Colors.primary = Color(prismLight: 0x4272EF, dark: 0x9DB8F9)`. The initializer is in `Look.swift`, the one file that names UIKit and AppKit ([ADR 0009](0009-swift-target.md), decision 1): a `UIColor` with a dynamic provider on the trait collection's `userInterfaceStyle` on iOS, an `NSColor(name:dynamicProvider:)` on the appearance's best match of `.aqua` and `.darkAqua` on macOS. SwiftUI resolves such a color against the view's environment, so the system's setting, `.preferredColorScheme(_:)` and `.environment(\.colorScheme, _)` all reach it. The names don't change, so an app that reads `Prism.Colors` changes nothing. No component draws in a system color when its look has none (the select's chevron, Flux 10550924645, is fixed on its own).
   - **Kotlin.** A color scheme of Prism's own, next to the light one, in Compose's form: `PrismColorScheme`, an immutable class with every color token, and `Prism.lightColorScheme` and `Prism.darkColorScheme`, as Material has `lightColorScheme()` and `darkColorScheme()`. `PrismTheme(darkTheme: Boolean = isSystemInDarkTheme()) { … }` provides it through a composition local, and `PrismTheme.colors` reads it, the system's choice where no `PrismTheme` is above. A component's looks take the scheme (`PrismTextFieldLooks(colors, …)`) instead of reading `Prism.Colors`, which goes. Material's `ColorScheme` stays the app's: [ADR 0015](0015-kotlin-target.md) keeps Prism's names out of Material's roles.
   - **Design tools.** `tokens.json` stays the light values, so a tool that imports one file gets what it gets today. `tokens.dark.json` has every color token's dark value at the same path, and `tokens.resolver.json` names the two as the contexts `light` and `dark` of one modifier, `color-scheme`, in the DTCG Resolver Module 2025.10 ([resolver](https://www.designtokens.org/tr/2025.10/resolver/)), the form for modes that DTCG defines. `tokens.css` gets the web's three blocks. `overview.svg` shows each swatch's two values, and draws the component sheets twice, the second time in dark on the dark background. How Figma, Penpot, pen.dev and Paper take a second mode is checked against each tool's documentation in that part, as the README's import steps were.
   - **Webflow.** The Designer Extension writes the light values into the collection's base mode, as now, and the dark values into a mode named `Dark` in the same collection, which it creates when missing (`createVariableMode`, and `variable.set(value, { mode })` in the Designer API typings 2.2.2, which ADR 0014's fake follows). Webflow's modes are manual or follow a breakpoint, not the system, so the site applies `Dark` where it wants it (decision 4).

4. **Follow the system, unless the app chooses.** The default on every target is the system's setting: the web's `prefers-color-scheme`, iOS's and macOS's appearance, Android's dark theme. An app that has its own setting, or isn't ready for dark mode, chooses, for the whole app or for a part:

   | Target | The whole app | A part |
   |---|---|---|
   | Web, Phoenix, React | `data-prism-color-scheme="light"` or `"dark"` on `<html>` | the same attribute on the part's element |
   | Swift | `.preferredColorScheme(.light)` or `.dark` on the window's root view | `.environment(\.colorScheme, .dark)` on the view |
   | Kotlin | `PrismTheme(darkTheme = …)` around the app's content | `PrismTheme(darkTheme = true)` around the part |
   | Design tools | the tool's mode for the file or frame | the tool's mode for the layer |
   | Webflow | the `Dark` mode on the body's class | the `Dark` mode on the element's class |

   The attribute's name follows CSS's `color-scheme` and SwiftUI's `colorScheme`. On the web, following the system with an app's own choice needs no script: the attribute wins where it is set.

5. **`inverse` goes.** It meant "a component on a dark background". With dark mode, a dark part of a light page is a part in dark mode (decision 4): the field there gets the dark field, the dark focus color, the dark label, which `inverse` never gave it (its field stayed white). The `inverse` variants of the text field, the text area, the field and the select are removed. The spinner's `inverse` meant "on a colored fill" as well, which dark mode doesn't cover, so it is renamed `on_color` and drawn in `oncolor` (white on a fill in light mode, dark on the lighter fills of dark mode). There is no alias and no shim: no consumer uses `inverse`, and Phoenix's compile-time check, TypeScript, Swift and Kotlin each name a left-over use when an app upgrades.

6. **Checks.**

   - **Both values, everywhere.** The schema refuses a color without its dark value in a design with both modes (decision 1). `design/test/tokens_test.exs` checks that Prism's design has both modes, so the rule can't be switched off by removing every `dark:`, and that no component names a literal color. Each target's test checks that its two sets name the same tokens: the three CSS blocks in `base.css` and `tokens.css`, every `Color(prismLight:dark:)` in `Tokens.swift`, `tokens.json` against `tokens.dark.json`; Kotlin's compiler does it for `PrismColorScheme`, whose constructor takes every token.
   - **Contrast.** A test in `design/` computes each pair the components draw, in each mode, from `__schema__/0`: a part's foreground on its background, or on the component's, or on `background` where neither has one, a fill at alpha composited over what is under it; and a border, an outline or a mark against what is around it. It takes the cells the overview draws (every variant, tone, flag and state, [ADR 0005](0005-design-tools.md), decision 6), and the typography of each to tell text from large text. Disabled looks are left out. Dark mode has no exceptions. Light mode's present misses are a reviewed list in the test, like the golden diff: a new miss fails, and a fixed one must leave the list, so a change shows in review either way. The thresholds are Prism's choice, so the test is in `design/`; `generator/` stays generic.
   - **Per target, both modes.** The generator's fixtures get a second example design with both modes, so each target's reviewed files show the dark output (`generator/test/fixtures/`). The web: Elixir tests on the CSS blocks, the custom properties and the mask. Swift: the macOS test already draws every component in light and dark; it checks that each component's colors are the mode's tokens (the chevron included), and the simulator test renders in dark too. Kotlin: the Robolectric test renders every component under `PrismTheme(darkTheme = true)` and checks its colors against `Prism.darkColorScheme`. Design tools: `tokens.dark.json` against the DTCG 2025.10 schema and through the parsers ADR 0005 uses, and `tokens.resolver.json` against the Resolver Module's schema. Webflow: the fake of the Designer API gets modes, and the tests cover creating `Dark`, setting values per mode, and an unchanged second run.
   - **The compare** ([#63](https://github.com/novasoftwarefoundation/prism/pull/63)) makes each target's default-size image in dark too, `compare-android-100-dark.png`, `compare-ios-default-dark.png` and `compare-web-100-dark.png`, on the dark background, and the page shows them in a row of their own. The release attaches nine images; `release-workflow.test.mjs`'s pin of Compare's `attach` job changes with it.

7. **The split, in build order.** Each part is one Flux issue and one pull request. Parts 2 to 6 need part 1 and are independent of each other; part 7 needs all of them, since a target that can't write a dark value fails a design that has one (ADR 0001, decision 3: nothing is silently ignored).

   | # | Part | What | Size |
   |---|---|---|---|
   | 1 | Design source and checks | The schema's `dark:` and its rules, with the second example design; until its part lands, each target refuses a design with both modes, by name. Prism's design gets the new tokens of decision 1 at their light values, with the components moved onto them (no visible change, a reviewed golden diff if any). The contrast test, in light, with today's misses listed. | M |
   | 2 | Web, Phoenix and React | The custom properties and their three blocks, the component CSS on them, the check mark as a mask, the preset's colors and `darkMode`; the README's section on the attribute. Phoenix and React get no code, a test each that the attribute switches the colors, and their READMEs. | L |
   | 3 | Swift | `Color(prismLight:dark:)` in `Look.swift`, the tokens and shadows on it; the macOS and simulator tests in dark; the README. | M |
   | 4 | Kotlin | `PrismColorScheme`, `Prism.lightColorScheme` and `darkColorScheme`, `PrismTheme`; the looks take the scheme; the Robolectric test in dark; the README. | L |
   | 5 | Design tools | `tokens.dark.json`, `tokens.resolver.json`, the dark blocks in `tokens.css`, the overview's dark sheets; their checks; each tool's import steps for a second mode, checked against its documentation. | M |
   | 6 | Webflow | The `Dark` mode: created when missing, values per mode, the fake with modes; the README for the site's developer. | S |
   | 7 | Prism's dark palette | The dark values of decision 2, as Melle settles them, in `design/lib/tokens.ex`; the contrast test in dark; `inverse` removed and the spinner's renamed (decision 5); the compare's dark images; the release notes, with the upgrade step for apps not ready for dark mode (decision 4). | M |

## Alternatives

| Option | Why not |
|---|---|
| A second set of tokens for dark (`mode :dark do … end`, or a dark design module) | The pair is on two lines in two places, so a missing or stale dark value isn't on the line of its token. One token with two values is what each target writes anyway (a custom property in two blocks, a dynamic color, a scheme's property), and the schema can refuse a missing value on its line (ADR 0001, decision 5). |
| Tokens without a dark value fall back to their light value | Silent: a new token would be light in dark mode until someone notices. `dark: :same` says it on purpose. |
| A full role layer (`text`, `textsubtle`, `border`, `fill`, …) on top of the hue tokens | The greys already work as roles by step, so turning the scale over keeps every use right but the two that play a second role. A full layer would rename most of the design's colors for the same result. |
| Keep the hue tokens fixed and give components a dark look of their own (a `dark` state or binding) | Per-mode code in every component, the thing the shared look removes. |
| Dark tone colors that keep white text on fills | No single blue gives both text on `#222222` and white on itself 4.5:1: the first needs a relative luminance of at least 0.25, the second at most 0.18. Tones would need two tokens each (question 2). |
| The web's `light-dark()` with `color-scheme` as the switch | One declaration per token, but Tailwind 3's `dark:` variant can't follow `color-scheme`, so an app's own utilities and Prism would switch apart; and it needs Safari 17.5. |
| A class (`.prism-dark`) instead of the data attribute | A class can clash with an app's own; the attribute says what it is and takes `light` too, for a light part of a dark page. |
| A React provider or context for the mode | The CSS already switches; a provider adds a render and a flash before hydration for nothing. |
| An asset catalog for the Swift colors | A resource bundle and a lookup by name (`Color("primary", bundle: .module)`) the compiler doesn't check, for what a dynamic provider does in code. |
| Generate Material's `ColorScheme` in Kotlin | Material's roles are not Prism's names ([ADR 0015](0015-kotlin-target.md)); Prism's own scheme keeps them, in Compose's form. |
| Dark values inside `tokens.json` under `$extensions.prism` | Tool-specific data where DTCG has a module for modes; no tool would read it. |
| Keep `inverse` beside dark mode | Two ways to say "dark here", and the old one leaves the field white. |
| Light by default, dark only when the app asks | Not what the issue asks: the platforms expect apps to follow the system. An app not ready says `light` once (decision 4). |

## Consequences

- An app follows the system's dark mode with Prism's components when it upgrades, also where its own screens don't yet. An app not ready sets `light` once, on its root (decision 4); the release notes say so.
- The web's component CSS and preset depend on the custom properties in `base.css`: an app imports both files, as the README already says. An app can override a custom property and change Prism's look; that is not a theming API.
- The golden diff against 0.1.7 grows by every hex the component CSS now writes as a custom property.
- `Prism.Colors` goes from the Kotlin library (`PrismTheme.colors`, `Prism.lightColorScheme`); the Swift names stay. The `inverse` variants and classes go; the spinner's is `on_color`.
- Every new color token needs its dark value, or `dark: :same`, or the design doesn't compile.
- Webflow can't follow the system with a mode; a site that wants that adds its own CSS.
- A high-contrast mode (`prefers-contrast`, iOS's Increase Contrast) would be a third value per token by the same rule; it is not part of this decision.
