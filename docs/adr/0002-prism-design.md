# 0002: Prism's design: 0.1.7's values, fonts per platform

Status: proposed, 2026-10-31

## Context

Prism is a look for scientific software: a Tailwind preset plus component CSS, published as `@novasoftwarefoundation/prism`. Native apps need the same look: iOS now, Android later. Today a native app copies the values by hand, and the web's component CSS doesn't use the preset's own tokens.

[ADR 0001](0001-design-format.md) records the design format and the generator. This ADR records Prism's own choices: the design in `design/`.

## Decision

1. **The source of truth is prism 0.1.7's styling:** `tailwind.preset.js`, `css/base.css` and `css/components.css`. `Prism.Design.Tokens` (`design/lib/tokens.ex`) reproduces 0.1.7's tokens as they are, inconsistencies included, so nothing changes for existing consumers. Each later clean-up is its own pull request with a visible golden diff.

2. **Three folders, two Mix projects.** `generator/` is the generic generator (`:prism_generator`), `design/` is Prism's design (`:prism_design`, depending on `{:prism_generator, path: "../generator"}`), and `targets/` holds what is generated. There is no Mix project at the root. `design/config/config.exs` names the design and the folder of each target (`design: Prism.Design.Tokens, targets: [web: "../targets/web"]`). The npm package is published from `targets/web/`, with the same name, version and files as before. `css/components.css` stays hand-written until the components are in the design.

3. **Prism's web naming** comes from the `web` declaration in `Prism.Design.Tokens`: the class prefix `prism`, fonts in `../fonts`, three line-clamp classes, and 0.1.7's comments at the top of the files.

4. **Fonts per platform.** Prism has two roles:
   - `:display` for headings (> 20px): Nunito on the web;
   - `:text` for body text (≤ 20px): Nunito Sans on the web.

   Both are `:system` on iOS and Android. While iOS uses `:system`, the Swift package bundles no fonts, so there is no font generator and no TTF files in it. `font :mono` stays as it is in 0.1.7 for now: the `:text` role at weight 300, not a monospaced font.

5. **Byte-compatibility with 0.1.7.** The generator's web spelling matches 0.1.7 (upper-case hex and two-decimal alphas in the preset, `0px` in text shadows, `0` in box shadows, prettier's 80-column wrap). `design/test/golden/0.1.7/` holds 0.1.7's files, and a test requires the generated files to differ from them only by the header line and the reviewed diff in `design/test/golden/0.1.7.diff`.

   Today that diff is one line: the deprecated `floating` shadow is an alias of `prism-card`, so it is written `0 5px 20px 0` instead of `0px 5px 20px 0px`, the same computed value. Any other change to the generated files fails the test until the diff file is updated, so it shows in review.

6. **Brand-neutrality and theming:** the design holds Prism's defaults. It keeps 0.1.7's behaviour: the preset is overridable, the component CSS is not. Emitting CSS custom properties for theming is a possible later change, not part of this decision.

7. **One version for Prism.** `design/mix.exs` has the same version as `targets/web/package.json`, and a test checks it. The generator has its own version (0.1.0). A release tag `vX.Y.Z` will be the npm version and, later, the Swift package's version. 0.x rules apply: a removed token, class or variant is a minor bump.

8. **Type styles.** Every role in either list (fonts and text sizes) has a `typography` token of the same name, and every font and text size is used by one; a test checks both. The format is in [ADR 0001](0001-design-format.md); this records Prism's pairings.

   - **A role in both lists pairs with itself**, 22 in all: `typography :title1, font: :title1, text: :title1`.
   - **The nine roles in only one list** are paired as the main consumer app combines Prism 0.1.7's classes today (2026-10-31): its typography reference page (an admin page that shows each style with its font and size class), its screens, and its rich-text styles. Where nothing uses a role, it pairs like its closest sibling.

   | Type style | Font | Text size | Evidence |
   |---|---|---|---|
   | `body` | `body` (text, 300) | `bodymedium` (20/30) | The most common pair on screens: `font-body text-bodymedium` about 50 times, against about 25 for `bodysmall`. It is also the base of rich text, and what 0.1.7's input, textarea and dropdown use (300 at 20/30 in `css/components.css`). |
   | `bold` | `bold` (text, 700) | `bodymedium` | Used for `strong` in rich text, on top of the rich text's base size, `text-bodymedium` (`text-bodylarge` from the small breakpoint). Its two other uses add it to a heading that already has a font class, with no size of its own. |
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

## Consequences

- Prism's look is edited in `design/lib/tokens.ex` and regenerated with `cd design && mix prism.gen`; CI fails (`mix prism.gen --check`) when the committed files differ.
- The generator can move to its own repository by moving `generator/` out and changing one dependency line in `design/mix.exs`; nothing in Prism's design changes.
- Swift comes later in `targets/swift/`, with its own `Package.swift`. It and Kotlin get type from the 31 type styles; a new font or text size needs a type style too, or the design's test fails.
- 0.1.7's inconsistencies stay until someone changes them on purpose.
