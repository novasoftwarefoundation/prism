# 0013: A font names an emphasis; each family gives it a weight

Status: proposed, 2026-11-09

## Context

A font named a weight: `font :title1, :display, 800`, `font :body, :text, 300`. The weights were tuned to Nunito and Nunito Sans, the web's fonts, and every target copied them. Since iOS binds both families to the system font ([ADR 0002](0002-prism-design.md), decision 4), iOS drew SF Pro at those weights: titles at 800 (Heavy), body text at 300 (Light). The same weight looks heavier in SF Pro than in Nunito, so a title in the app looked bolder than the same title on the web (Flux 10486071094: "Profile" on the Account page, iPhone 17).

A weight belongs to one font. What the design means holds in every font: a page's title stands out more than a subheading, and a subheading more than running text. The weight that draws it differs per font. Naming that meaning after a font weight (`:bold`) would bring the problem back: on iOS, `:bold` would draw SF Pro Semibold.

## Decision

1. **A font names an emphasis: what its text is for, and so how much it stands out.** The emphases are declared once, lightest first:

   ```elixir
   emphases [:reading, :data, :supporting, :subheading, :strong, :headline]
   font :title1, :display, :headline
   ```

   | Emphasis | What it is for | Typography today |
   |---|---|---|
   | `reading` | running text people read | body, bodymedium, bodysmall, bodylarge, hint, mono |
   | `data` | values in a table | tablerow |
   | `supporting` | text that goes with the content: captions, footnotes, intros, links | caption, captionsmall, footnote, intro, introdesktop, link, bodylinklarge, bodylinkmedium |
   | `subheading` | a heading inside a section | subhead |
   | `strong` | text of strong importance, as HTML's `<strong>`: actions, labels, short titles | button, buttonsmall, label, labelsmall, tablehead, title5, title6, title7, quote, bold |
   | `headline` | a page's large titles | title0 to title4 |

   Prism has six because its fonts used six weights (300 to 800), and Nunito and Nunito Sans keep each one. No name is a font weight's (no `light`, `bold`) or a number. A component's `emphasis:` (the link button's, on top of its typography) names one too: `emphasis: :supporting`. Other systems resolve such names per typeface too: Material's `md.ref.typeface.weight-*`, Atlassian's `font.weight.*`; Prism names what the text is for instead of the weight.

2. **Each family's binding gives every emphasis a weight of its font**, its `scale:`: every emphasis, in order, each one of 100, 200, …, 1000, none lighter than the one before. Two emphases may share a weight.

   ```elixir
   @nunito [reading: 300, data: 400, supporting: 500, subheading: 600, strong: 700, headline: 800]
   @sf_pro [reading: 300, data: 400, supporting: 400, subheading: 500, strong: 600, headline: 700]

   family :display,
     doc: "Headings (> 20px)",
     web: [name: "Nunito", fallback: "sans-serif", faces: [...], scale: @nunito],
     ios: {:system, scale: @sf_pro},
     android: {:system, scale: @nunito}
   ```

   The system font is `{:system, scale: …}`, a named font `[name:, faces:, scale:]`. A binding without a scale, an emphasis declared after a family, a scale that misses an emphasis or has one out of order, and a font or an `emphasis:` that names no emphasis fail at compile time. `Prism.Generator.Schema.weight(family, platform, emphasis)` gives the weight.

3. **Each target takes the weight from the binding of its platform.**
   - Web: the preset's `font-…` classes and `components.css` take the web scale's weight. A component's `emphasis:` takes the weight in the family of the typography its element has: its node's, else the nearest along its path (for a part, the part's own look before the root's); an emphasis with no typography to weigh fails generation.
   - Design tools: a font's `fontWeight` is the web scale's weight, as the files describe the web's fonts; `tokens.css` and the overview the same. The iOS and Android scales are not in the files.
   - React and Phoenix write no weight: their components use `components.css`.
   - Swift: `PrismEmphasis` is an enum of the emphases; `PrismFontFamily` is the font (`.system` or `.named(…)`) and the iOS scale's weight of each emphasis (`Prism.Families.display.strong` is 600, `weight(_:)` reads it). `PrismTypography.emphasis` and `PrismLook.emphasis` are a `PrismEmphasis`, `.emphasis(_:)` sets one, and the font is drawn at `typography.weight`, the family's weight for it.
   - Android has no target; its scale is today's weights until one reads it.

4. **SF Pro's weights are measured, not guessed.** On the iOS 26.3 simulator each Typography was drawn in Nunito or Nunito Sans at the web's weight and in SF Pro at 100 to 900, at its size and at Dynamic Type AX2, and the width of the stem of "l" compared; the closest SF Pro weight was the same at both sizes for all fifteen Typography sampled, and the same for both families. Side by side in Safari and SwiftUI, titles, body text, labels, buttons and hints then look as heavy in the app as on the web.

   | Emphasis | Nunito, Nunito Sans | SF Pro |
   |---|---|---|
   | reading | 300 | 300 |
   | data | 400 | 400 |
   | supporting | 500 | 400 |
   | subheading | 600 | 500 |
   | strong | 700 | 600 |
   | headline | 800 | 700 |

## Consequences

- The web and design-tool files are byte for byte the same as before; the 0.1.7 golden test and `mix prism.gen --check` show it.
- An iOS app draws headlines one step lighter (SF Pro Bold instead of Heavy), subheadings and strong text one step lighter, supporting text as data. Reading text stays light.
- No backwards compatibility: a design names emphases, not weights. In Swift, `PrismFontFamily.system` is `PrismFontFamily(.system, reading: …)`, `PrismTypography(weight: 800, …)` is `PrismTypography(emphasis: .headline, …)`, `.weight(700)` is `.emphasis(.strong)`, `PrismLook(weight:)` is `PrismLook(emphasis:)`, and `typography.weight` is now the drawn weight (an `Int`).
- Binding iOS to Nunito later ([ADR 0009](0009-swift-target.md), decision 7) is a change of the iOS binding and its scale, `@nunito`.
