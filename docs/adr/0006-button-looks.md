# 0006: Button looks: tones on every variant, soft, icon, padded, the icon's side

Status: proposed, 2026-10-31

## Context

[ADR 0002](0002-prism-design.md) took Prism's button from 0.1.7: five variants (`primary`, `secondary`, `plain`, `link`, `text`), a `tone` axis whose `success`, `warning` and `danger` colored the background whatever the variant, and an icon that always came after the label. Decision 10 left two things open: `text` was to be checked against the main consumer app's own button looks, and there was no icon-only button.

That app's buttons need more than this. It colors outlined and text buttons red or green, has dark grey and yellow buttons, a red button on a light red background, icon-only buttons, plain and text buttons as tall as a primary button beside them as well as ones that fit their text, and icons on either side of the label (Flux 10462845635). Without these, it would keep coloring Prism's buttons with its own utility classes.

The changes are in 0.2.0, which isn't released yet.

## Decision

1. **A tone colors by one rule.** A tone colors the background of a `primary` button (with white text, or dark grey on yellow), and the text, and the border where there is one, of `secondary`, `plain`, `link` and `text`. Radix's solid, outline and ghost buttons and Material 3's filled, outlined and text buttons use their color the same way. A tone's look is therefore a look with each variant (`with_variant`, [ADR 0001](0001-design-format.md)), not a look of its own: on the web, `.prism-button--secondary.prism-button--danger`. A tone without a variant has no look: a button has no variant by default, and then only its base look.

2. **Two more tones, from Prism's tokens.** `neutral` is `grey1` (dark grey, `#222222`), with white text on a primary button. `highlight` is `tertiary` (yellow, `#FFCF60`), with `grey1` text on a primary button. `highlight` joins decision 10's tone vocabulary of ADR 0002: `accent`, `neutral`, `highlight`, `info`, `success`, `warning`, `danger`. Following the rule, a secondary, plain, link or text button in `highlight` has yellow text, which reads poorly on white; the rule is kept, and an app picks the tone where it reads.

3. **A soft variant.** `soft` has the tone's light color as its background and the tone's color as its text, as Radix's "soft" button. It is laid out and pressed as a primary button (padding 15/16, the same pressed shadow and disabled opacity, the same spacing with an icon). Its own look is accent's: `primarylight` behind `primary`. The light colors are Prism's existing tokens: `successlight`, `warninglight`, `errorlight` for `success`, `warning`, `danger`. `neutral` and `highlight` have no light color, so `soft` has no look with them: a `soft` button in either tone looks as a soft accent button. The schema doesn't refuse the combination, since the format has no way to say that two variants don't combine; adding light tokens for them is a later design change.

4. **An icon variant.** `icon` is an icon only: 24×24, no padding, at opacity 0.8 while pressed. The app gives the icon in the button's `icon` part and a label for assistive technology (`aria-label`). The variant has the name of the part: their classes, `--icon` and `__icon`, can't be confused, so the format allows a variant to share a part's name ([ADR 0001](0001-design-format.md)). It takes no tone: its color is the icon's.

5. **Padded plain and text buttons, by default.** A `padded` flag, on by default: a plain or text button as tall as a primary or secondary button beside it (padding 15px top and bottom, 16px at the sides, and 16/14 while pressed). With `padded` off, it fits its text: 1px top and bottom, no padding at the sides (2/0 while pressed). The variants' own looks are the unpadded ones, and the flag's looks are with `plain` and `text`; it has no look with the other variants yet. On the web the flag is the class `prism-button--padded`, which the Phoenix and React components add by default on a plain or text button (`padded={false}` leaves it off). This changes both variants from 0.1.7: `plain` was 4px top and bottom, `text` 1px top and bottom and 16px at the sides.

6. **The icon's side.** The app puts the icon at the `:start` (the default) or the `:end` of the label, as Fluent's `iconPosition` (whose values are `before` and `after`): the part's `position:` in the design ([ADR 0001](0001-design-format.md)), `icon_position` in Phoenix and `iconPosition` in React. `start` and `end` follow the text's direction, so they stay right in right-to-left languages, where left and right would not. The components put the icon's element before or after the label's, so a flex row lays them out in the text's direction with no CSS of its own. Before, the icon always came after the label; in the components it now comes before it unless the app says `:end`.

## Alternatives

| Option | Why not |
|---|---|
| A tone keeps one look for every variant | It colors the background of an outlined or text button too, which no design system does. |
| Two parts, `start_icon` and `end_icon`, as MUI's `startIcon` and `endIcon` | No new format mechanism, but two names for one icon, and a button could get both. One icon with a side is Fluent's model, and keeps one `with_icon` look. |
| Fluent's `before` and `after` | `start` and `end` are the names CSS uses for the same idea (`margin-inline-start`, `justify-content: flex-end`). |
| `left` and `right` | Wrong in right-to-left languages. |
| A `size` axis for compact plain and text buttons | The difference is padding, not size: the typography and the icon stay the same. |
| `padded` off by default | Most of the app's text buttons line up beside a primary one (its compact text buttons are about one in five). Its plain buttons are mostly compact today and take `padded={false}`; one default for both variants keeps the setting simple. |
| Refusing `soft` with `neutral` or `highlight` | The format has no way to declare that two variants don't combine, and the components can't refuse a combination the app picks at runtime without TypeScript unions per variant. Left out, documented, until light tokens exist. |

## Consequences

- An app colors a button with its tone on any variant, and has no color overrides left for the looks the app has today.
- `css/components.css` changes: the tones' rules become rules with each variant, `plain` and `text` lose their 0.1.7 padding without `--padded`, and `soft`, `icon`, `neutral`, `highlight` and `padded` are new. The golden diff (`design/test/golden/0.1.7.diff`) holds every change.
- Phoenix and React components add `--padded` to plain and text buttons and put the icon first unless told otherwise.
- The format gains `with_variant`, `flag` and a part's `position:` ([ADR 0001](0001-design-format.md)), which other components can use too.
