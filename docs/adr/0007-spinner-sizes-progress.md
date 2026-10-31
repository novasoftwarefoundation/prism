# 0007: Spinner sizes by their pixels, a progress value, 20px in the button

Status: proposed, 2026-11-01

## Context

[ADR 0002](0002-prism-design.md) took Prism's spinner from 0.1.7: 24px, with `small` (16px) and `large` (32px) as a `size` axis, drawn as an arc that turns. The main consumer app needs more than that (Flux 10463131361):

- a spinner that also shows how far something is, for uploads and an import: a light grey full ring (the track) with an arc in the spinner's color as long as the progress, which keeps turning. The app has drawn it itself, at 30px and 20px;
- a spinner of 20px. A loading button's spinner is 24px today, large beside the 18px label in a 48px button;
- a 16px spinner inside a small control, as another app of the foundation draws its own.

A size name like `small` says nothing about the pixels, and a fourth size would need a fourth name between `small` and `medium`. These changes are in 0.2.0, which isn't released yet.

## Decision

1. **Sizes are named by their pixels: 16, 20, 24 and 32.** 24 is the spinner's own size and the default, with no class, as `medium` was; 16 and 32 replace `small` and `large`, and 20 is new. There are no aliases: 0.2.0 is unreleased, and the web README's migration table maps 0.1.7's `prism-spinner-sm` and `-lg` to `--16` and `--32` directly. The classes are `prism-spinner--16`, `--20` and `--32`; Phoenix takes `size={16}` and React `size={16}`.
   - The format gets **variants named by a number** ([ADR 0001](0001-design-format.md)): `variant 16, size: 16`, a whole number above 0. An axis's variants, its aliases and its default are all names or all numbers, so a Phoenix attribute has one type (`:integer` here) and a React prop one union (`16 | 20 | 24 | 32`, in their order). The web class is the number (`--16`). A native target will prefix it with the axis (`size16`), as Swift and Kotlin names can't start with a digit.
   - Fluent's spinner and SwiftUI's control sizes name sizes by words (`tiny`, `small`, `large`). A spinner's sizes are only pixels, though, with nothing else that changes per size, so the number says all there is, and leaves room for another size without a new word.

2. **A progress value from 0 to 100.** Without one, the spinner is exactly today's spinner: the same image, the same markup, no role. With one:
   - the spinner draws a full **track** in `grey4` (`#EEEEEE`) and an **arc** in the spinner's color (`currentColor`) whose length is the value, starting at the top and going clockwise, with round ends. `grey4` is Prism's token closest to the light grey (`#e0e0e0`) the app draws its track in; the next grey, `grey3` (`#CCCCCC`), is darker and further from it;
   - the line is 16 of the spinner's box of 100 (16%), thicker than the spinner's own, so the arc reads at 16px. The ring's radius is 42, so the line stays inside the box;
   - it **keeps turning**, as the spinner does, so it still says "busy" while the number stands still;
   - a value below 0 or above 100 is **clamped**. At 0 there is the track and no arc: a dash of length 0 with round ends would still draw a dot;
   - its semantics are a **progress bar**: `role="progressbar"` with `aria-valuenow` (the clamped value), `aria-valuemin="0"` and `aria-valuemax="100"`. A progress bar needs a name, which only the app knows (what is loading): it gives one with `aria-label` or `aria-labelledby`, which the components pass on to the element. Without a value, the spinner's semantics stay as they are: the app labels it (`role="status"`, `aria-label`) where it needs to.

   The design holds only this look: `value :progress, stroke: {16, :percent}, track: :grey4` on the spinner. The app gives only the number (`progress={40}`).

3. **The format gets a `value` node and two properties** ([ADR 0001](0001-design-format.md)). A `value` is a number from 0 to 100 that the app gives or leaves out, and whose look the design gives: the look while the app gives it, nothing else. `stroke` is the width of a line a component draws, such as a ring's; `track` is the color of the line beyond a value's length. A target knows the values of its components by name, as it knows their parts, and draws what follows the number: the web knows the spinner's `:progress`, and fails generation for any other value, as it does for an unknown part. A value shares the component's names with its variants, states and flags, since its class (`--progress`) is a modifier too.

4. **The mechanics are the generator's.** On the web the ring is an SVG in the spinner's element: a box of 100, a `__track` circle and, above 0, an `__indicator` circle whose `pathLength` is 100 and whose `stroke-dasharray` is the value followed by 100, so the app's number is the arc's length as it is, with no arithmetic in the markup. `Prism.Generator.Web.Elements` writes that markup once, as data, and the Phoenix and React components render it; `components.css` turns the image off for `--progress` and draws the circles: the value's `stroke` as their width, its `track` as the track's color, the indicator in `currentColor`. The web refuses a stroke in px or rem for the spinner's progress, since the ring is drawn in a box of 100. The design-tool overview draws a row for the value, at 40. A native target will draw the same look with its own platform's ring (SwiftUI's trimmed `Circle`, Compose's `CircularProgressIndicator` with a `trackColor`).

5. **The loading button's spinner is 20px.** The format gets a part's `variants:` ([ADR 0001](0001-design-format.md)): a part that is another component picks that component's variants, one per axis, by their names. The button's spinner part is `part :spinner, component: :spinner, variants: [size: 20]`, so the components render `prism-spinner prism-spinner--20` in a loading button, and the button centers it by half of 20px. A size of its own on the part would have been a second way to size a spinner, beside the sizes it has.

## Alternatives

| Option | Why not |
|---|---|
| Keep `small` and `large` and add a fourth name (`medium-small`, `x-small`) | A name per size says less than the size, and the next one needs another word. |
| Keep `small` and `large` as aliases of 16 and 32 | 0.2.0 is unreleased and renames every other class; an alias would be a second name to keep. |
| Size names as strings or atoms (`:"16"`, `"16"`) | `size={:"16"}` reads poorly, and a number says what it is: the attribute and the prop take the number. |
| A separate `progress` component | It is the spinner with one more look: the same sizes, colors and turning. A second component would repeat them. |
| The progress drawn in CSS with a `conic-gradient` and a custom property | No round ends, and the app would set a style property instead of a value. |
| The arc's length by `stroke-dashoffset` over the circumference (2πr) | The app's number would need arithmetic in the markup; `pathLength="100"` makes the number the length. |
| A size of its own on the button's spinner part (`part :spinner, size: 20`) | A second way to size a spinner; picking the size variant keeps one. |
| The track in `grey3` (`#CCCCCC`) | Further from the app's light grey than `grey4`, and heavier behind a thin arc. |

## Consequences

- An app sizes a spinner by its pixels and shows a progress with one number; its own progress spinner goes.
- `css/components.css` changes: `--small` and `--large` become `--16` and `--32`, `--20` and `--progress` (with its ring's rules) are new, and a loading button centers its spinner by 10px instead of 12px. The golden diff (`design/test/golden/0.1.7.diff`) holds every change.
- The Phoenix and React components: `size` takes a number, `progress` is new, and a loading button renders its spinner with `prism-spinner--20`.
- The format gains variants named by numbers, the `value` node with the `stroke` and `track` properties, and a part's `variants:`, which other components can use too. A value on another component needs its drawing in each target first.
