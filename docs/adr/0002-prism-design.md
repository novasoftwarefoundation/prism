# 0002: Prism's design: 0.1.7's values, fonts per platform

Status: proposed, 2026-10-31

## Context

Prism is a look for scientific software: a Tailwind preset plus component CSS, published as `@novasoftwarefoundation/prism`. Native apps need the same look: iOS now, Android later. Today a native app copies the values by hand, and the web's component CSS doesn't use the preset's own tokens.

[ADR 0001](0001-design-format.md) records the design format and the generator. This ADR records Prism's own choices: the design in `design/`.

## Decision

1. **The source of truth is prism 0.1.7's styling:** `tailwind.preset.js`, `css/base.css` and `css/components.css`. `Prism.Design.Tokens` (`design/lib/tokens.ex`) reproduces 0.1.7's tokens as they are, inconsistencies included, and the components keep 0.1.7's look under the names of decision 10. Each later clean-up is its own pull request with a visible golden diff.

2. **Three folders, two Mix projects.** `generator/` is the generic generator (`:prism_generator`), `design/` is Prism's design (`:prism_design`, depending on `{:prism_generator, path: "../generator"}`), and `targets/` holds what is generated. There is no Mix project at the root. `design/config/config.exs` names the design and the folder of each target (`design: Prism.Design.Components, targets: [web: "../targets/web"]`): `Prism.Design.Components` takes its tokens from `Prism.Design.Tokens`, so it is the whole design. The npm package is published from `targets/web/`, with the same name, version and files as before. All three web files are generated.

3. **Prism's web naming** comes from the `web` declaration in `Prism.Design.Tokens`: the class prefix `prism`, fonts in `../fonts`, three line-clamp classes, and 0.1.7's comments at the top of the files. `Prism.Design.Components` adds the comment at the top of `css/components.css`.

4. **Fonts per platform.** Prism has two roles:
   - `:display` for headings (> 20px): Nunito on the web;
   - `:text` for body text (≤ 20px): Nunito Sans on the web.

   Both are `:system` on iOS and Android. While iOS uses `:system`, the Swift package bundles no fonts, so there is no font generator and no TTF files in it. `font :mono` stays as it is in 0.1.7 for now: the `:text` role at weight 300, not a monospaced font.

5. **Compatibility with 0.1.7, recorded.** The generator's web spelling matches 0.1.7 (upper-case hex and two-decimal alphas in the preset, `0px` in text shadows, `0` in box shadows, prettier's 80-column wrap). `design/test/golden/0.1.7/` holds 0.1.7's files, and `design/test/golden_test.exs` compares the generated files with them:

   - The preset and `css/base.css` are 0.1.7's files but for one line: the deprecated `floating` shadow is an alias of `prism-card`, so it is written `0 5px 20px 0` instead of `0px 5px 20px 0px`, the same computed value.
   - `css/components.css` is 0.1.7's file with every class renamed by the table of decision 10, which the test holds too. The test fails when a 0.1.7 class is missing from the table, or its new class from the generated CSS, so nothing is lost silently. What differs beyond the rename (the button with an icon, the spinner, the comments) is in the same reviewed diff.

   Both are in `design/test/golden/0.1.7.diff`, and the generated files must differ from 0.1.7 (renamed) only by the header line and that diff. Any other change fails the test until the diff file is updated, so it shows in review.

6. **Brand-neutrality and theming:** the design holds Prism's defaults. It keeps 0.1.7's behaviour: the preset is overridable, the component CSS is not. Emitting CSS custom properties for theming is a possible later change, not part of this decision.

7. **One version for Prism.** `design/mix.exs` has the same version as `targets/web/package.json`, and a test checks it. The generator has its own version (0.2.0). A release tag `vX.Y.Z` will be the npm version and, later, the Swift package's version. 0.x rules apply: a removed token, class or variant is a minor bump, so decision 10's new class names are 0.2.0 (a consumer on `^0.1.7` doesn't take it by accident).

8. **Typography.** Every role in either list (fonts and text sizes) has a `typography` token of the same name, and every font and text size is used by one; a test checks both. The format is in [ADR 0001](0001-design-format.md); this records Prism's pairings.

   - **A role in both lists pairs with itself**, 22 in all: `typography :title1, font: :title1, text: :title1`.
   - **The nine roles in only one list** are paired as the main consumer app combines Prism 0.1.7's classes today (2026-10-31): its typography reference page (an admin page that shows each typography token with its font and size class), its screens, and its rich-text styles. Where nothing uses a role, it pairs like its closest sibling.

   | Typography | Font | Text size | Evidence |
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

   - `body` and `bodymedium` are the same typography under two names. Both stay, so no role in either list is missing a typography token.
   - `bodylinklarge` is 24px in the `:text` family, above decision 4's 20px line. Both families are `:system` on iOS and Android, so nothing differs natively today; moving it to `:display` would be a later clean-up.
   - **Screens that differ from the name pairing.** Screens write `bodylarge` as `font-body text-bodylarge` (about 14 times; `font-bodylarge` is never used) and `introdesktop` as `font-intro text-introdesktop`, and the reference page writes `mono` with `font-body` (the same values as `font-mono`). These still pair by name. This decision covers only the roles in one list, and the name pairing keeps 0.1.7's own fonts: Nunito for `bodylarge` and `introdesktop`, as the reference page's own labels say ("Nunito Light", "Nunito Medium"). Following the screens instead would be a design change with its own pull request.

9. **Prism's components.** `Prism.Design.Components` (`design/lib/components.ex`) holds 0.1.7's eleven components, under the names of decision 10: `button`, `text_field`, `text_area`, `field`, `radio_group` and `radio` (0.1.7's radio, split in two), `select`, `spinner`, `checkbox`, `tag`, `message_bar` and `step_indicator`. The format is in [ADR 0001](0001-design-format.md).

   - **Structure.** The button's variants are emphasis (`primary`, `secondary`, `plain`, `link`, `text`), and `success`, `warning` and `danger` are a second axis, `tone`, which combines with one; without a tone a button is accent. [ADR 0006](0006-button-looks.md) adds the variants `soft` and `icon`, the tones `neutral` and `highlight`, the rule by which a tone colors each variant, the `padded` flag and the icon's side. With an icon (its `icon` part), the primary, secondary and plain buttons are spaced as 0.1.7's `-icon` buttons: a `with_part :icon`, not a variant (the web class `--with-icon`). The button's loading state hides its `label` part and centers its `spinner` part, which is the spinner component; while not loading, the spinner is hidden. The text field's `invalid` is a state (the app sets `prism-text-field--invalid`). The field is a label and an error message (`label`, `error_message`) around a control. The radio group holds the radios; a radio is the row with its `control` and its `label`, and its `disabled` state is a class the app sets on the row. The spinner's sizes are the axis `size`, named by their px (16, 20 and 32; [ADR 0007](0007-spinner-sizes-progress.md)), its colors the variants `accent` and `inverse`, and its `progress` a value (ADR 0007); a loading button's spinner is 20px; the tag's and message bar's colors are the axis `tone`, the step indicator's the axis `status`.
   - **Defaults** (`default:`, ADR 0001): a button's tone is `accent` and a spinner's size `24`, names without a class, since they are the component's own look; a tag's tone is `accent`, a message bar's `info` and a step indicator's status `incomplete`, the variants 0.1.7's comments call the default. A button's `variant`, a text field's and a spinner's color have none: a button without a variant has only its base look, and a spinner without a color takes the text color around it.
   - **Hex values.** Every color in 0.1.7's `css/components.css` is a token but one:

     | 0.1.7 | Token | Used by |
     |---|---|---|
     | `#4272ef` | `primary` | button variants, focus borders, checked controls, the selected option, tags, message bars, the current step, the accent spinner |
     | `#ffffff` | `white` | button text, field and list backgrounds, the base tag, step indicators, the inverse spinner |
     | `#222222` | `grey1` | plain button, field and label text |
     | `#cccccc` | `grey3` | field and control borders, disabled text field text |
     | `#999999` | `grey2` | placeholders, the incomplete step, the neutral tag (at 20%) |
     | `#f6f6f6` | `grey5` | disabled text field, hovered option |
     | `#eeeeee` | `grey4` | the incomplete step |
     | `#ffcf60` | `tertiary` | focus border of the inverse text field |
     | `#52ba12`, `#f28d15`, `#db1e1e` | `success`, `warning`, `error` | tones of buttons, tags and message bars (at 20% and 15%); `warning` is also the invalid text field's border and the error message's color |
     | `#666666` | none | the neutral tag's text: a literal `"#666666"` |

   - **Other values that aren't tokens** are literals of their type, not new tokens:
     - lengths (padding, gaps, sizes, heights, margins, offsets) are px: the spacing tokens are the preset's Tailwind steps and don't cover them (16px, 12px, 32px);
     - the checkbox's `4px` radius is a literal; `radius :default` is `0.25rem`, the same size at the default root font size but another CSS value;
     - opacities (0.5, 0) and durations (150ms, 100ms, 1s) have no tokens in the format;
     - the link button's weight 500 is a weight on top of the button's typography;
     - tags and message bars write 600 at 14/16 (the `subhead` font with the `tablehead` text size) and the step indicator 700 at 12/12 (the `label` font, and 12/12, which is no text size). No typography token has these, so each is a literal pair. New typography tokens would break decision 8's rule that the typography tokens are the roles of the two lists, and a new 12/12 text size would add a `text-…` class to the preset.
     - The other components use typography tokens: `button` for the button and the select's options, `body` for the text field, text area and select field, `title6` for the field's label (700 at 20/22), `caption` for its error message, `label` for the radio's label.
   - **The deprecated `top2px`** is the secondary buttons' pressed shadow, as in 0.1.7; it has no replacement yet.
   - **Web bindings** hold only what is the web's own: the comments of `css/components.css` (`section:`, `doc:`).
   - **The spinner** is drawn in its color: its `foreground`, a token like any other (`primary` for `accent`, `white` for `inverse`; without a variant, the text color around it). 0.1.7 tinted a black image with CSS filter chains, one tuned by hand per color; the web now draws a spinner image as a mask over `background-color: currentColor`, so any color works and a color change needs no new filter. The image is inline in `css/components.css`, a `data:` URI like the check mark's: apps import the CSS into their own stylesheet, where a relative URL would resolve against the app and the spinner would not load. The spinner is an empty element (`<span class="prism-spinner">`), no longer an image.
   - **Web mechanics** are the generator's (`Prism.Generator.Web.Components`), among them the select list's `z-index: 20`, the step indicator's tabular numbers and the spinner's mask.

10. **Names: the ones design systems share.** Components, parts, variants and states are named after what Material 3 and Compose, SwiftUI and Apple's HIG, Carbon, Fluent 2, Polaris, Atlassian and Spectrum call them, so a name means the same on every target Prism generates for. 0.1.7's names were its CSS classes; the web's classes follow the new names (ADR 0001, decision 3), so `css/components.css` changes on purpose.

    - **Avoid a name that means something else on a platform.** Dropped for that reason: `alert` (a modal on iOS and Android, an assertive live region on the web; now `message-bar`, as Fluent), `dropdown` (an action menu in Compose and Carbon; now `select`), `label` as a button variant (SwiftUI's `Label` is an icon with a title; now `text`, as Material's text button), `active` for a step (CSS `:active` means pressed; now `current`), `number-icon` and `stepper` (iOS's stepper is a plus/minus control; now `step-indicator`). A same-named type with the same meaning (`Button`) is fine; native generators will namespace Prism's types.
    - **Full words**, no `btn`, `sm` or `lg`.
    - **Look only.** `delete` was a purpose; the red tone is `danger`.
    - **Separate axes:** `variant` (emphasis), `tone` (color meaning), `size` (the spinner's px, 16, 20 and 32; the default is 24 and has no class; [ADR 0007](0007-spinner-sizes-progress.md)), and `status` for a step.
    - **One tone vocabulary:** `accent`, `neutral`, `highlight` (added by [ADR 0006](0006-button-looks.md)), `info`, `success`, `warning`, `danger`. `danger` is the red tone and `invalid` the validation state, so "this is red" and "this value is wrong" stay apart. The aliases `delete` (button) and `error` (tag) are gone; `error` is also no longer a tag or message bar tone. A test checks the vocabulary.
    - **States are participles:** `hovered`, `focused`, `pressed`, `disabled`, `checked`, `selected`, `invalid`, `loading`.
    - `spinner` stays (not `progress-circle`): Prism targets Compose, not Android Views, where a spinner is a select. `text` replaces the `label` button; [ADR 0006](0006-button-looks.md) checked it against the main consumer app's own button looks and added the `padded` flag to it. 0.1.7 has no look for an icon-only button; ADR 0006 adds the `icon` variant.
    - **No compatibility layer.** No old class or alias is kept; consumers move to the new classes with the table below. It ships in 0.2.0.

    | 0.1.7 class | 0.2.0 class |
    |---|---|
    | `prism-btn` | `prism-button` |
    | `prism-btn-content` | `prism-button__label` |
    | `prism-btn-primary`, `-secondary`, `-plain`, `-link` | `prism-button--primary`, `--secondary`, `--plain`, `--link` |
    | `prism-btn-label` | `prism-button--text`, which has no padding at the sides (0.1.7's had 16px); with `prism-button--padded` it is 15px 16px ([ADR 0006](0006-button-looks.md), decision 5) |
    | `prism-btn-primary-icon`, `-secondary-icon`, `-plain-icon` | `prism-button--primary`, `--secondary`, `--plain` with `prism-button--with-icon` (and the icon as `prism-button__icon`) |
    | `prism-btn-success`, `-warning` | `prism-button--success`, `--warning` |
    | `prism-btn-danger`, `prism-btn-delete` | `prism-button--danger` |
    | `prism-btn-loading` | `prism-button--loading` |
    | `prism-input` | `prism-text-field` |
    | `prism-input-error` | `prism-text-field--invalid` |
    | `prism-input-dark` | `prism-text-field--inverse` |
    | `prism-textarea` | `prism-text-area` |
    | `prism-label` | `prism-field__label` |
    | `prism-label-error` | `prism-field__error-message` |
    | `prism-radio-group` | `prism-radio-group` |
    | `prism-radio-label` | `prism-radio` |
    | `prism-radio-label` with `disabled` | `prism-radio` with `prism-radio--disabled` |
    | `prism-radio` | `prism-radio__control` |
    | `prism-radio-text` | `prism-radio__label` |
    | `prism-dropdown` | `prism-select` |
    | `prism-dropdown-input` | `prism-select__field` |
    | `prism-dropdown-icon` | `prism-select__icon` |
    | `prism-dropdown-options` | `prism-select__listbox` |
    | `prism-dropdown-option` | `prism-select__option` |
    | `prism-dropdown-option` with `selected` | `prism-select__option` with `prism-select__option--selected` |
    | `prism-spinner` | `prism-spinner`, on an empty element |
    | `prism-spinner-sm`, `-lg` | `prism-spinner--16`, `--32` ([ADR 0007](0007-spinner-sizes-progress.md)) |
    | `prism-spinner-primary`, `-white` | `prism-spinner--accent`, `--inverse` |
    | `prism-checkbox` | `prism-checkbox` |
    | `prism-tag` | `prism-tag` |
    | `prism-tag-inner` | `prism-tag__label` |
    | `prism-tag-primary`, `-secondary` | `prism-tag--accent`, `--neutral` |
    | `prism-tag-success`, `-warning` | `prism-tag--success`, `--warning` |
    | `prism-tag-error`, `prism-tag-danger` | `prism-tag--danger` |
    | `prism-alert` | `prism-message-bar` |
    | `prism-alert-info`, `-success`, `-warning` | `prism-message-bar--info`, `--success`, `--warning` |
    | `prism-alert-error` | `prism-message-bar--danger` |
    | `prism-number-icon` | `prism-step-indicator` |
    | `prism-number-icon-inactive`, `-active`, `-completed` | `prism-step-indicator--incomplete`, `--current`, `--complete` |

    The utilities `prism-max-lines-*` and `prism-text-shadow*` (in `css/base.css`) are not components and keep their names.

    **Looks that change with the names.** A button with an icon now combines its variant with `--with-icon`, so it also takes the variant's disabled look (opacity 0.5), which 0.1.7's `-icon` buttons lacked; otherwise it looks as before, pressed too. The spinner is a mask in its color (decision 9), and a button hides its spinner while not loading, which the main consumer app did in its own CSS.

## Consequences

- Prism's look is edited in `design/lib/tokens.ex` and `design/lib/components.ex` and regenerated with `cd design && mix prism.gen`; CI fails (`mix prism.gen --check`) when the committed files differ.
- 0.2.0 breaks every app that uses 0.1.7's classes: each moves to the classes of decision 10 when it takes 0.2.0.
- The generator can move to its own repository by moving `generator/` out and changing one dependency line in `design/mix.exs`; nothing in Prism's design changes.
- Swift comes later in `targets/swift/`, with its own `Package.swift`. It and Kotlin get type from the 31 typography tokens; a new font or text size needs a typography token too, or the design's test fails.
- 0.1.7's inconsistencies stay until someone changes them on purpose.
