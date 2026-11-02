# 0010: The text field's prefix: a part at its start, and a wrapper while it is there

Status: proposed, 2026-11-02

## Context

A consumer app puts a currency inside its text field, at the start: the currency symbol, or a picker (a native select) when there are several currencies (Flux 10465599897). The part has a light grey background (`grey6`), a `grey3` line at its end, 12px at its sides, and the field's full height. The input after it has no border of its own: the box around both has the field's border, and takes the field's focused and invalid colors while the input has focus.

Prism's `text_field` is a single `<input>` on the web, and an `<input>` holds nothing. The format's `border` was also all four sides or none, so the line at the part's end couldn't be written.

## Decision

1. **A part named `prefix`.** Material 3 and Compose (`prefix`), Polaris (`prefix`) and Ant Design (`prefix`) name the content before a text field's text so; Fluent 2 says `contentBefore`, Atlassian `elemBeforeInput`, MUI `startAdornment`, and Carbon, Spectrum and SwiftUI have no such part. `prefix` is the name most of the design systems of [ADR 0002](0002-prism-design.md), decision 10, share. `leading` was not taken: Compose's `leadingIcon` is an icon, and the part holds text or a picker. `addon` is Ant Design's and Bootstrap's word for a boxed part, which none of decision 10's systems use. The app fills the part: a symbol, or its own picker. It is at the start, in the text's direction; the format has no `suffix` yet.

2. **On the web, a wrapper while the prefix is there.** Without a prefix, the text field is the `<input>` it was, with the same classes. With one, it is a `<div>` with the text field's classes and `--with-prefix`, around the prefix (`<span class="prism-text-field__prefix">`) and the input (`<input class="prism-text-field__input">`):

   ```html
   <div class="prism-text-field prism-text-field--invalid prism-text-field--with-prefix">
     <span class="prism-text-field__prefix">€</span>
     <input class="prism-text-field__input" name="amount" />
   </div>
   ```

   - **The wrapper takes the text field's look**: its border, background, radius, height, text, and the looks of its variants and states. So the design's text field doesn't change for it, and the app's classes (`class`, `className`) go on the wrapper.
   - **The input takes the app's attributes and the element's own states**: `name`, `value`, `id`, `phx-*`, the ref, and `disabled`. Its CSS is mechanics only: it fills the rest of the row, takes the wrapper's text, has no border or background, and has the text field's padding, which the wrapper then doesn't have.
   - **Its states are its input's**: the text field is focused while its input has focus (`:focus-within`), and disabled while its input is (`:is(:disabled, :has(> :disabled))`). Both hold on the `<input>` itself too, so a text field without a prefix keeps its look, and the weight of the selectors is the same as before (`:focus`, `:disabled`). A design whose text field has no prefix part keeps `:focus` and `:disabled`.
   - **The prefix fills the height** at the start, and doesn't shrink.
   - The Phoenix and React components render the wrapper while the app gives the prefix (`<:prefix>`, `prefix`), and the input otherwise, from the same markup data (`Prism.Generator.Web.Elements`).

3. **On iOS, a modifier with a prefix view.** `.prismTextField(focused:invalid:) { Text("€") }` lays the prefix and the `TextField` side by side, the prefix filling the height, the text in the field's padding after it, and the field's box around both. Without the trailing closure, the modifier is as before. The prefix is any view: a `Text`, or the app's `Picker`.

4. **The format's border may be on some sides**: `border: [width: 1, color: :grey3, sides: [:right]]`. The sides are padding's (`top`, `right`, `bottom`, `left`, `x`, `y`): the web writes `border-right`, iOS draws the line on the trailing side, as padding's `right` is trailing there. Without `sides:`, a border is on every side, as before. A state that changes a border's color changes it on the sides the border has.

5. **Prism's prefix**: `part :prefix, background: :grey6, padding: [x: 12], border: [width: 1, color: :grey3, sides: [:right]]`. Its text is the field's (grey1 at `body`; grey3 while disabled), so it sets none.

## Alternatives

| Option | Why not |
|---|---|
| The text field always a wrapper | Every app's text field markup and CSS would change, for a part most fields don't have. |
| A separate component (`text_field_group`, an input group) | Two components with one look; every state and variant of the text field would be repeated in the group. |
| The wrapper as the app's own markup, with only the prefix's look in Prism | Each app would write the border, focus and invalid looks again around the input: the drift Prism removes. |
| The wrapper's states as classes the app sets (`--focused`) | Focus is the browser's; `:focus-within` follows it without the app. |
| The prefix's line as a background with a 1px gap | The line's color would be the wrapper's background, which the disabled state changes. |
| A border's sides as `start` and `end` | Padding names its sides `left` and `right`; one vocabulary for sides keeps the format simple. On iOS both follow the text's direction already. |

## Consequences

- An app puts a currency, or its own picker, before a text field's text, and the field's border, focus, invalid and disabled looks hold around both, on the web and on iOS.
- `components.css`: Prism's text field rules use `:focus-within` and `:is(:disabled, :has(> :disabled))` instead of `:focus` and `:disabled`, with the same weight and the same look on an `<input>`. The prefix, the input and the wrapper are new rules. The golden diff (`design/test/golden/0.1.7.diff`) holds them.
- An app that styles `.prism-text-field:focus` or `.prism-text-field:disabled` itself, at the same weight, may need its rule after Prism's CSS, or to match the new selectors, for the wrapper.
- The format's `border` takes `sides:` on any component.
- Adding or removing the prefix on a field that is on screen swaps its element (React remounts the input, LiveView patches in a new one), so the input loses its focus and an uncontrolled value. A field that may get a prefix has one from its first render; the READMEs say so.
- An app's own focus color on an invalid field uses `:focus-within` (`focus-within:` in Tailwind), which holds on the plain input and on the wrapper.
