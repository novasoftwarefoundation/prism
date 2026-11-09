# 0013: A font names a weight; each family gives it a number of its font

Status: proposed, 2026-11-09

## Context

A font named a number: `font :title1, :display, 800`, `font :body, :text, 300`. The numbers were tuned to Nunito and Nunito Sans, the web's fonts, and every target copied them. Since iOS binds both families to the system font ([ADR 0002](0002-prism-design.md), decision 4), iOS drew SF Pro at those numbers: titles at 800 (Heavy), body text at 300 (Light). The same number looks heavier in SF Pro than in Nunito, so a title in the app looked bolder than the same title on the web (Flux 10486071094: "Profile" on the Account page, iPhone 17).

A number is the weight of one font. What a design means, a title heavier than its body text, holds in every font; the number that draws it differs per font.

## Decision

1. **The weights are declared once, lightest first**, and a font names one:

   ```elixir
   weights [:light, :regular, :medium, :semibold, :bold, :extrabold]
   font :title1, :display, :extrabold
   ```

   Prism has six because its fonts used six numbers (300 to 800), and Nunito and Nunito Sans keep each one. The names are Nunito's own instances (Light, Regular, Medium, SemiBold, Bold, ExtraBold), written as the design writes compound names (`:primarylight`, `:bodylarge`). Other systems name weights per font the same way: Material's `md.ref.typeface.weight-medium`, Atlassian's `font.weight.semibold`, both resolved per typeface. A component's `weight:` (the link button's, on top of its typography) names a weight too: `weight: :medium`.

2. **Each family's binding gives every weight a number of its font**, its `scale:`: every weight, in order, each one of 100, 200, …, 1000, none lighter than the one before. Two weights may share a number.

   ```elixir
   @nunito [light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, extrabold: 800]
   @sf_pro [light: 300, regular: 400, medium: 400, semibold: 500, bold: 600, extrabold: 700]

   family :display,
     doc: "Headings (> 20px)",
     web: [name: "Nunito", fallback: "sans-serif", faces: [...], scale: @nunito],
     ios: {:system, scale: @sf_pro},
     android: {:system, scale: @nunito}
   ```

   The system font is `{:system, scale: …}`, a named font `[name:, faces:, scale:]`. A binding without a scale, a weight declared after a family, a scale that misses a weight or has one out of order, and a font or a `weight:` that names no weight fail at compile time. `Prism.Generator.Schema.weight(family, platform, weight)` gives the number.

3. **Each target takes the number from the binding of its platform.**
   - Web: the preset's `font-…` classes and `components.css` take the web scale's number. A component's `weight:` takes the number in the family of the typography its element has: its node's, else the nearest along its path (for a part, the part's own look before the root's); a weight with no typography to weigh fails generation.
   - Design tools: a font's `fontWeight` is the web scale's number, as the file describes the web's fonts; `tokens.css` and the overview the same. The iOS and Android scales are not in the files.
   - React and Phoenix write no weight: their components use `components.css`.
   - Swift: `PrismWeight` is an enum of the weights; `PrismFontFamily` is the font (`.system` or `.named(…)`) and the iOS scale's number of each weight (`Prism.Families.display.bold` is 600, `number(_:)` reads it). `PrismTypography.weight` and `PrismLook.weight` are a `PrismWeight`; the font is drawn at `typography.number`, the family's number for it.
   - Android has no target; its scale is today's numbers until one reads it.

4. **SF Pro's numbers are measured, not guessed.** On the iOS 26.3 simulator each Typography was drawn in Nunito or Nunito Sans at the web's number and in SF Pro at 100 to 900, at its size and at Dynamic Type AX2, and the width of the stem of "l" compared; the closest SF Pro weight was the same at both sizes for all fifteen Typography sampled, and the same for both families. Side by side in Safari and SwiftUI, titles, body text, labels, buttons and hints then look as heavy in the app as on the web.

   | Weight | Nunito, Nunito Sans | SF Pro |
   |---|---|---|
   | light | 300 | 300 |
   | regular | 400 | 400 |
   | medium | 500 | 400 |
   | semibold | 600 | 500 |
   | bold | 700 | 600 |
   | extrabold | 800 | 700 |

## Consequences

- The web and design-tool files are byte for byte the same as before; the 0.1.7 golden test and `mix prism.gen --check` show it.
- An iOS app draws titles one step lighter (SF Pro Bold instead of Heavy), semibold and bold one step lighter, medium as regular. Body text stays light.
- No backwards compatibility: a design names weights, not numbers. In Swift, `PrismFontFamily.system` is `PrismFontFamily(.system, light: …)`, `PrismTypography(weight: 800, …)` is `PrismTypography(weight: .extrabold, …)`, `.weight(700)` is `.weight(.bold)`, and `PrismLook(weight:)` takes a `PrismWeight`.
- Binding iOS to Nunito later ([ADR 0009](0009-swift-target.md), decision 7) is a change of the iOS binding and its scale, `@nunito`.
