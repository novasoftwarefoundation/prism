# 0002: Prism's design: 0.1.7's values, fonts per platform

Status: proposed, 2026-10-31

## Context

Prism is a look for scientific software: a Tailwind preset plus component CSS, published as `@novasoftwarefoundation/prism`. Native apps need the same look: iOS now, Android later. Today a native app copies the values by hand, and the web's component CSS doesn't use the preset's own tokens.

[ADR 0001](0001-design-format.md) records the design format and the generator. This ADR records Prism's own choices: the design in `design/`.

## Decision

1. **The source of truth is prism 0.1.7's styling:** `tailwind.preset.js`, `css/base.css` and `css/components.css`. `Prism.Design.Tokens` (`design/lib/tokens.ex`) reproduces 0.1.7's tokens as they are, inconsistencies included, so nothing changes for existing consumers. Each later clean-up is its own pull request with a visible golden diff.

2. **Three folders, two Mix projects.** `generator/` is the generic generator (`:prism_generator`), `design/` is Prism's design (`:prism_design`, depending on `{:prism_generator, path: "../generator"}`), and `targets/` holds what is generated. There is no Mix project at the root. `design/config/config.exs` names the design and the folder of each target (`design: Prism.Design.Components, targets: [web: "../targets/web"]`): `Prism.Design.Components` takes its tokens from `Prism.Design.Tokens`, so it is the whole design. The npm package is published from `targets/web/`, with the same name, version and files as before. All three web files are generated.

3. **Prism's web naming** comes from the `web` declaration in `Prism.Design.Tokens`: the class prefix `prism`, fonts in `../fonts`, three line-clamp classes, and 0.1.7's comments at the top of the files. `Prism.Design.Components` adds the comment at the top of `css/components.css`.

4. **Fonts per platform.** Prism has two roles:
   - `:display` for headings (> 20px): Nunito on the web;
   - `:text` for body text (≤ 20px): Nunito Sans on the web.

   Both are `:system` on iOS and Android. While iOS uses `:system`, the Swift package bundles no fonts, so there is no font generator and no TTF files in it. `font :mono` stays as it is in 0.1.7 for now: the `:text` role at weight 300, not a monospaced font.

5. **Byte-compatibility with 0.1.7.** The generator's web spelling matches 0.1.7 (upper-case hex and two-decimal alphas in the preset, `0px` in text shadows, `0` in box shadows, prettier's 80-column wrap). `design/test/golden/0.1.7/` holds 0.1.7's files, and a test requires the generated files to differ from them only by the header line and the reviewed diff in `design/test/golden/0.1.7.diff`.

   Today that diff is one line: the deprecated `floating` shadow is an alias of `prism-card`, so it is written `0 5px 20px 0` instead of `0px 5px 20px 0px`, the same computed value. `css/components.css` adds nothing to it: it is 0.1.7's file byte for byte. Any other change to the generated files fails the test until the diff file is updated, so it shows in review.

6. **Brand-neutrality and theming:** the design holds Prism's defaults. It keeps 0.1.7's behaviour: the preset is overridable, the component CSS is not. Emitting CSS custom properties for theming is a possible later change, not part of this decision.

7. **One version for Prism.** `design/mix.exs` has the same version as `targets/web/package.json`, and a test checks it. The generator has its own version (0.1.0). A release tag `vX.Y.Z` will be the npm version and, later, the Swift package's version. 0.x rules apply: a removed token, class or variant is a minor bump.

8. **Type styles.** Every role in either list (fonts and text sizes) has a `typography` token of the same name, and every font and text size is used by one; a test checks both. The format is in [ADR 0001](0001-design-format.md); this records Prism's pairings.

   - **A role in both lists pairs with itself**, 22 in all: `typography :title1, font: :title1, text: :title1`.
   - **The nine roles in only one list** are paired as the main consumer app combines Prism 0.1.7's classes today (2026-10-31): its typography reference page (an admin page that shows each style with its font and size class), its screens, and its rich-text styles. Where nothing uses a role, it pairs like its closest sibling.

   | Type style | Font | Text size | Evidence |
   |---|---|---|---|
   | `body` | `body` (text, 300) | `bodymedium` (20/30) | The most common pair on screens: `font-body text-bodymedium` about 50 times, against about 25 for `bodysmall`. It is also the base of rich text, and what 0.1.7's input, textarea and dropdown use (300 at 20/30 in `css/components.css`). |
   | `bold` | `bold` (text, 700) | `bodymedium` | Used for `strong` in rich text, on top of the rich text's base size, `text-bodymedium` (`text-bodylarge` from the small breakpoint). Its two other uses are on headings that bring their own size: one also has a font class and a title size, the other is a test-harness heading with Tailwind's `text-2xl` and no Prism font class. |
   | `bodymedium` | `body` | `bodymedium` | The reference page; about 50 uses on screens. |
   | `bodysmall` | `body` | `bodysmall` (16/24) | The reference page; about 25 uses on screens. |
   | `captionsmall` | `caption` (text, 500) | `captionsmall` (12/14) | The reference page; `font-caption text-captionsmall` in two components (a small tag and a button face). |
   | `labelsmall` | `label` (text, 700) | `labelsmall` (14/14) | The reference page only. |
   | `buttonsmall` | `button` (text, 700) | `buttonsmall` (16/16) | The reference page only. |
   | `bodylinklarge` | `link` (text, 500) | `bodylinklarge` (24/36) | Not used. Paired like its sibling `link`. |
   | `bodylinkmedium` | `link` | `bodylinkmedium` (30/30) | One use, by mistake: a link writes `font-bodylinkmedium` (no such font class) with `text-body` (no such size), so neither class has an effect; it means a link in body text. Paired like its sibling `link`. |

   - `body` and `bodymedium` are the same style under two names. Both stay, so no role in either list is missing a type style.
   - `bodylinklarge` is 24px in the `:text` family, above decision 4's 20px line. Both families are `:system` on iOS and Android, so nothing differs natively today; moving it to `:display` would be a later clean-up.
   - **Screens that differ from the name pairing.** Screens write `bodylarge` as `font-body text-bodylarge` (about 14 times; `font-bodylarge` is never used) and `introdesktop` as `font-intro text-introdesktop`, and the reference page writes `mono` with `font-body` (the same values as `font-mono`). These still pair by name. This decision covers only the roles in one list, and the name pairing keeps 0.1.7's own fonts: Nunito for `bodylarge` and `introdesktop`, as the reference page's own labels say ("Nunito Light", "Nunito Medium"). Following the screens instead would be a design change with its own pull request.

9. **Prism's components.** `Prism.Design.Components` (`design/lib/components.ex`) holds 0.1.7's eleven components: `btn`, `input`, `textarea`, `label`, `radio`, `dropdown`, `spinner`, `checkbox`, `tag`, `alert` and `number_icon`. The format is in [ADR 0001](0001-design-format.md).

   - **Names.** Every component, variant, part and state is named as its 0.1.7 class (`btn`, `primary_icon`, `number_icon`, the radio's `group`, `label` and `text`), because a class is made of the design's names. Each name is written once in `design/lib/components.ex`. Renaming to other names is its own pull request, and the CSS changes with it on purpose.
   - **Structure.** The button's `success`, `warning` and `danger` (alias `delete`) are a second axis, `:color`, which combines with a variant of the first; the spinner's sizes and colors are the axes `:size` and `:color`. The button's loading state hides its `content` part and centers its `spinner` part, which is the spinner component. The input's `error` is a state (the app sets `.prism-input-error`); the label's `error` is a variant, because `.prism-label-error` is a label of its own. The radio component is the control itself; `group`, `label` and `text` are its parts.
   - **Hex values.** Every color in 0.1.7's `css/components.css` is a token but one:

     | 0.1.7 | Token | Used by |
     |---|---|---|
     | `#4272ef` | `primary` | button variants, focus borders, checked controls, the selected option, tags, alerts, the active number icon |
     | `#ffffff` | `white` | button text, field and list backgrounds, the base tag, number icons |
     | `#222222` | `grey1` | plain button, field and label text |
     | `#cccccc` | `grey3` | field and control borders, disabled input text |
     | `#999999` | `grey2` | placeholders, the inactive number icon, the secondary tag (at 20%) |
     | `#f6f6f6` | `grey5` | disabled input, hovered option |
     | `#eeeeee` | `grey4` | the inactive number icon |
     | `#ffcf60` | `tertiary` | focus border of the dark input |
     | `#52ba12`, `#f28d15`, `#db1e1e` | `success`, `warning`, `error` | color variants, tags, alerts (at 20% and 15%); `warning` is also the input's and the label's error color |
     | `#666666` | none | the secondary tag's text: a literal `"#666666"` |

   - **Other values that aren't tokens** are literals of their type, not new tokens:
     - lengths (padding, gaps, sizes, heights, margins, offsets) are px: the spacing tokens are the preset's Tailwind steps and don't cover them (16px, 12px, 32px);
     - the checkbox's `4px` radius is a literal; `radius :default` is `0.25rem`, the same size at the default root font size but another CSS value;
     - opacities (0.5, 0) and durations (150ms, 100ms, 1s) have no tokens in the format;
     - the link button's weight 500 is a weight on top of the button's type style;
     - tags and alerts write 600 at 14/16 (the `subhead` font with the `tablehead` text size) and the number icon 700 at 12/12 (the `label` font, and 12/12, which is no text size). No type style has these, so each is a literal pair. New type styles would break decision 8's rule that type styles are the roles of the two lists, and a new 12/12 text size would add a `text-…` class to the preset.
     - The other components use type styles: `button` for the button and the dropdown's options, `body` for the fields, `title6` for the label (700 at 20/22), `caption` for the label's error, `label` for the radio's text.
   - **The deprecated `top2px`** is the secondary buttons' pressed shadow, as in 0.1.7; it has no replacement yet.
   - **Web bindings** hold only what is the web's own: the comments of `css/components.css` (`section:`, `doc:`), and the filter that tints the spinner image `primary`. That filter is tuned to `#4272EF`, so it is a value of Prism's, not a mechanic: generic mechanics can't produce it. Its binding names the color it was made for, and generation fails when `primary` changes. White is written by the generator itself.
   - **Web mechanics** are the generator's (`Prism.Generator.Web.Components`), among them the dropdown list's `z-index: 20` and the number icon's tabular numbers.

## Consequences

- Prism's look is edited in `design/lib/tokens.ex` and `design/lib/components.ex` and regenerated with `cd design && mix prism.gen`; CI fails (`mix prism.gen --check`) when the committed files differ.
- The generator can move to its own repository by moving `generator/` out and changing one dependency line in `design/mix.exs`; nothing in Prism's design changes.
- Swift comes later in `targets/swift/`, with its own `Package.swift`. It and Kotlin get type from the 31 type styles; a new font or text size needs a type style too, or the design's test fails.
- 0.1.7's inconsistencies stay until someone changes them on purpose.
