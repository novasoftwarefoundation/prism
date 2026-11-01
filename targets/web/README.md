# @novasoftwarefoundation/prism

A Tailwind-based UI framework for scientific software.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

## Features

- **Brand-neutral design** - Decoupled from specific branding for maximum third-party adoption
- **Hybrid approach** - Both Tailwind preset (for customization) and ready-made component classes
- **Variable fonts** - Uses Nunito and Nunito Sans variable fonts for optimal typography
- **Easy to adopt** - Drop-in CSS classes for common components
- **iOS too** - The same design for SwiftUI, tokens and components, in the Swift package [`prism-swift`](https://github.com/novasoftwarefoundation/prism-swift) at the same version (since 0.2.0)

## Installation

```bash
npm install @novasoftwarefoundation/prism
```

## Usage

### 1. Configure Tailwind

Add the Prism preset to your `tailwind.config.js`:

```javascript
module.exports = {
  presets: [require("@novasoftwarefoundation/prism/tailwind.preset")],
  content: [
    // your content paths
  ],
};
```

### 2. Import CSS

Import the base and component styles in your main CSS file:

```css
@import "@novasoftwarefoundation/prism/css/base.css";
@import "@novasoftwarefoundation/prism/css/components.css";

@tailwind base;
@tailwind components;
@tailwind utilities;
```

### 3. Use Components

Classes follow BEM: `prism-<component>`, `__<part>` for a part, `--<name>` for a variant or a state the app sets.

```html
<!-- Buttons: a variant, and optionally a tone -->
<button class="prism-button prism-button--primary">
  <span class="prism-button__label">Primary Button</span>
</button>
<button class="prism-button prism-button--secondary">
  <span class="prism-button__label">Secondary Button</span>
</button>
<button class="prism-button prism-button--primary prism-button--danger">
  <span class="prism-button__label">Delete</span>
</button>
<!-- A tone colors a primary button's background, and the others' text and border -->
<button class="prism-button prism-button--secondary prism-button--danger">
  <span class="prism-button__label">Delete</span>
</button>
<!-- Soft: the tone's light color behind its color -->
<button class="prism-button prism-button--soft prism-button--danger">
  <span class="prism-button__label">Delete</span>
</button>

<!-- Plain and text buttons: --padded lines them up beside a primary button;
     without it, they fit their text -->
<button class="prism-button prism-button--text prism-button--padded">
  <span class="prism-button__label">Cancel</span>
</button>
<button class="prism-button prism-button--text">
  <span class="prism-button__label">Show more</span>
</button>

<!-- A button with an icon: the icon part, and --with-icon for its spacing. The icon
     goes before the label (at its start) or after it (at its end). -->
<button class="prism-button prism-button--primary prism-button--with-icon">
  <img class="prism-button__icon" src="add.svg" alt="" />
  <span class="prism-button__label">Add</span>
</button>
<button class="prism-button prism-button--plain prism-button--padded prism-button--with-icon">
  <span class="prism-button__label">Next</span>
  <img class="prism-button__icon" src="forward.svg" alt="" />
</button>

<!-- An icon only, 24×24 -->
<button class="prism-button prism-button--icon prism-button--with-icon" aria-label="Close">
  <img class="prism-button__icon" src="close.svg" alt="" />
</button>

<!-- A loading button: the spinner (20px) shows only while --loading is set -->
<button class="prism-button prism-button--primary prism-button--loading">
  <span class="prism-button__label">Save</span>
  <span class="prism-spinner prism-spinner--20"></span>
</button>

<!-- Fields -->
<label class="prism-field__label" for="name">Name</label>
<input id="name" type="text" class="prism-text-field" placeholder="Enter text" />
<input type="text" class="prism-text-field prism-text-field--invalid" aria-invalid="true" />
<span class="prism-field__error-message">Required</span>
<textarea class="prism-text-area" placeholder="Enter description"></textarea>

<!-- Radio buttons -->
<div class="prism-radio-group">
  <label class="prism-radio">
    <input type="radio" name="option" class="prism-radio__control" />
    <span class="prism-radio__label">Option 1</span>
  </label>
  <label class="prism-radio prism-radio--disabled">
    <input type="radio" name="option" class="prism-radio__control" disabled />
    <span class="prism-radio__label">Option 2</span>
  </label>
</div>

<!-- Select -->
<div class="prism-select">
  <input type="text" class="prism-select__field" value="Select option" />
  <div class="prism-select__listbox">
    <div class="prism-select__option prism-select__option--selected">Option 1</div>
    <div class="prism-select__option">Option 2</div>
  </div>
</div>

<!-- Spinner: an empty element, drawn in its text color -->
<span class="prism-spinner" role="status" aria-label="Loading"></span>
<span class="prism-spinner prism-spinner--16 prism-spinner--accent"></span>

<!-- Spinner with a progress value (40 of 100): a ring, the arc as long as the value -->
<span class="prism-spinner prism-spinner--32 prism-spinner--progress" aria-label="Uploading"
      role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="40">
  <svg viewBox="0 0 100 100" aria-hidden="true">
    <circle class="prism-spinner__track" cx="50" cy="50" r="42" />
    <circle class="prism-spinner__indicator" cx="50" cy="50" r="42" pathLength="100"
            stroke-dasharray="40 100" transform="rotate(-90 50 50)" />
  </svg>
</span>

<!-- Tags -->
<span class="prism-tag prism-tag--accent">
  <span class="prism-tag__label">New</span>
</span>
<span class="prism-tag prism-tag--success">
  <span class="prism-tag__label">Complete</span>
</span>

<!-- Message bars -->
<div class="prism-message-bar prism-message-bar--info">Information message</div>
<div class="prism-message-bar prism-message-bar--success">Success message</div>
<div class="prism-message-bar prism-message-bar--warning">Warning message</div>
<div class="prism-message-bar prism-message-bar--danger">Error message</div>

<!-- Step indicators -->
<span class="prism-step-indicator prism-step-indicator--complete">1</span>
<span class="prism-step-indicator prism-step-indicator--current">2</span>
<span class="prism-step-indicator prism-step-indicator--incomplete">3</span>
```

## Design Tokens

### Colors

| Token          | Value     | Usage                    |
| -------------- | --------- | ------------------------ |
| `primary`      | `#4272EF` | Primary actions, links   |
| `primarylight` | `#E3EAFD` | Primary backgrounds      |
| `secondary`    | `#FF5E5E` | Secondary actions        |
| `tertiary`     | `#FFCF60` | Accents, highlights      |
| `success`      | `#52BA12` | Success states           |
| `warning`      | `#F28D15` | Warning states, errors   |
| `error`        | `#DB1E1E` | Error states             |
| `grey1-6`      | Various   | Text and background greys|

### Typography

Prism uses a two-font system:
- **Nunito** - For larger text (>20px): titles, headings
- **Nunito Sans** - For smaller text (≤20px): body, labels, buttons

Font classes: `font-title0` through `font-title7`, `font-body`, `font-button`, `font-label`, etc.

## Component Classes

### Buttons

| Class | Description |
| --- | --- |
| `prism-button` | Base button (required) |
| `prism-button__label` | The button's label (hidden while loading) |
| `prism-button__icon` | The button's icon |
| `prism-button--primary` | Filled button |
| `prism-button--secondary` | Outlined button |
| `prism-button--plain` | Text only, no background; fits its text without `--padded` |
| `prism-button--link` | Looks like a text link |
| `prism-button--text` | Brand-colored text, minimal styling; fits its text without `--padded` |
| `prism-button--soft` | The tone's light color behind its color, laid out as a primary button |
| `prism-button--icon` | An icon only, 24×24, no padding or background; give it an `aria-label` |
| `prism-button--padded` | With `--plain` or `--text`: as tall as a primary button beside it (15px 16px) |
| `prism-button--with-icon` | Spacing for a button with an icon (with `--primary`, `--secondary`, `--plain` or `--soft`) |
| `prism-button--success`, `--warning`, `--danger`, `--neutral`, `--highlight` | Tones, with a variant: the background of `--primary`, the text (and border) of `--secondary`, `--plain`, `--link` and `--text`, the light background of `--soft` (no light color for `--neutral` and `--highlight`, so no soft look) |
| `prism-button--loading` | Loading: hides the label, shows the spinner |

### Fields

| Class | Description |
| --- | --- |
| `prism-text-field` | Single-line text field |
| `prism-text-field--invalid` | A text field with an invalid value |
| `prism-text-field--inverse` | A text field on a dark background |
| `prism-text-area` | Multi-line text field |
| `prism-field__label` | Form label |
| `prism-field__error-message` | Error message |

### Radio Buttons

| Class | Description |
| --- | --- |
| `prism-radio-group` | Container for radios |
| `prism-radio` | One option: the row with the control and its label |
| `prism-radio--disabled` | A disabled option |
| `prism-radio__control` | The radio input |
| `prism-radio__label` | The option's label |

### Select

| Class | Description |
| --- | --- |
| `prism-select` | Container |
| `prism-select__field` | The field that opens the list |
| `prism-select__icon` | The field's icon |
| `prism-select__listbox` | The list of options |
| `prism-select__option` | One option |
| `prism-select__option--selected` | The selected option |

### Spinner

| Class | Description |
| --- | --- |
| `prism-spinner` | Spinner (24px), in the text color around it |
| `prism-spinner--16`, `--20`, `--32` | Spinner of 16, 20 or 32px; 24px has no class |
| `prism-spinner--accent` | Accent colored |
| `prism-spinner--inverse` | White, for colored backgrounds; with a progress value, its track is white at 20% |
| `prism-spinner--progress` | With a progress value: a light grey ring with an arc in the spinner's color, as long as the value |
| `prism-spinner__track`, `prism-spinner__indicator` | The progress ring's two circles |

The spinner is an empty element drawn with an image (inline in `components.css`) as a mask over its text color, so a text color utility colors it too. A loading button's spinner is 20px.

With a progress value, the spinner holds an SVG ring instead of the image, in a box of 100 (see the example above): the indicator's `pathLength` is 100, so its `stroke-dasharray` is the value and 100. The ring's line is thicker than the spinner's own (16 of 100), and the spinner keeps turning. Give it `role="progressbar"` with `aria-valuenow`, `aria-valuemin` and `aria-valuemax`, and a name: `aria-label` (or `aria-labelledby`), saying what is loading. At 0, leave the indicator out: its round ends would still draw a dot. The Phoenix and React components write all of this from one number (`progress`), clamped to 0..100.

### Checkbox

| Class | Description |
| --- | --- |
| `prism-checkbox` | Checkbox input |

### Tags

| Class | Description |
| --- | --- |
| `prism-tag` | Base tag container |
| `prism-tag__label` | The tag's label |
| `prism-tag--accent` | Accent tag |
| `prism-tag--neutral` | Grey tag |
| `prism-tag--success`, `--warning`, `--danger` | Green, orange and red tags |

### Message Bars

| Class | Description |
| --- | --- |
| `prism-message-bar` | Base message bar |
| `prism-message-bar--info`, `--success`, `--warning`, `--danger` | Tones |

### Step Indicators

| Class | Description |
| --- | --- |
| `prism-step-indicator` | The numbered circle of one step |
| `prism-step-indicator--incomplete` | A step not reached yet |
| `prism-step-indicator--current` | The current step |
| `prism-step-indicator--complete` | A completed step |

## Migrating from 0.1.7

0.2.0 renames every component class to the names design systems share; no old class is kept. Replace each 0.1.7 class with its 0.2.0 class.

**Two names are reused, so rename these first:** `prism-radio` (0.1.7's input) becomes `prism-radio__control` before `prism-radio-label` becomes `prism-radio`. And a `prism-spinner` on an `<img>` becomes an empty `<span class="prism-spinner">` before anything else. Replacing the table from top to bottom would otherwise turn the radio's row into a control as well.

| 0.1.7 class | 0.2.0 class |
| --- | --- |
| `prism-btn` | `prism-button` |
| `prism-btn-content` | `prism-button__label` |
| `prism-btn-primary` | `prism-button--primary` |
| `prism-btn-secondary` | `prism-button--secondary` |
| `prism-btn-plain` | `prism-button--plain` |
| `prism-btn-link` | `prism-button--link` |
| `prism-btn-label` | `prism-button--text` (see below) |
| `prism-btn-primary-icon` | `prism-button--primary prism-button--with-icon` |
| `prism-btn-secondary-icon` | `prism-button--secondary prism-button--with-icon` |
| `prism-btn-plain-icon` | `prism-button--plain prism-button--with-icon` |
| `prism-btn-success` | `prism-button--success` |
| `prism-btn-warning` | `prism-button--warning` |
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
| `prism-radio-label disabled` | `prism-radio prism-radio--disabled` |
| `prism-radio` | `prism-radio__control` |
| `prism-radio-text` | `prism-radio__label` |
| `prism-dropdown` | `prism-select` |
| `prism-dropdown-input` | `prism-select__field` |
| `prism-dropdown-icon` | `prism-select__icon` |
| `prism-dropdown-options` | `prism-select__listbox` |
| `prism-dropdown-option` | `prism-select__option` |
| `prism-dropdown-option selected` | `prism-select__option prism-select__option--selected` |
| `prism-spinner` | `prism-spinner` |
| `prism-spinner-sm` | `prism-spinner--16` |
| `prism-spinner-lg` | `prism-spinner--32` |
| `prism-spinner-primary` | `prism-spinner--accent` |
| `prism-spinner-white` | `prism-spinner--inverse` |
| `prism-checkbox` | `prism-checkbox` |
| `prism-tag` | `prism-tag` |
| `prism-tag-inner` | `prism-tag__label` |
| `prism-tag-primary` | `prism-tag--accent` |
| `prism-tag-secondary` | `prism-tag--neutral` |
| `prism-tag-success` | `prism-tag--success` |
| `prism-tag-warning` | `prism-tag--warning` |
| `prism-tag-error`, `prism-tag-danger` | `prism-tag--danger` |
| `prism-alert` | `prism-message-bar` |
| `prism-alert-info` | `prism-message-bar--info` |
| `prism-alert-success` | `prism-message-bar--success` |
| `prism-alert-warning` | `prism-message-bar--warning` |
| `prism-alert-error` | `prism-message-bar--danger` |
| `prism-number-icon` | `prism-step-indicator` |
| `prism-number-icon-inactive` | `prism-step-indicator--incomplete` |
| `prism-number-icon-active` | `prism-step-indicator--current` |
| `prism-number-icon-completed` | `prism-step-indicator--complete` |

Also:

- **Spinner.** It is no longer a tinted image: use an empty element (`<span class="prism-spinner"></span>`, not an `<img>`). Its image is inline in `components.css` and drawn as a mask over its text color, so CSS that drew it as a mask in an app can go, and the app serves no image for it. In a button it shows only while the button has `prism-button--loading`.
- **Spinner sizes by their pixels.** `--16`, `--20` and `--32` (24px has no class); there is no `--small` or `--large`. In Phoenix `size={16}`, in React `size={16}`. A loading button's spinner is 20px (it was 24px): the components render `prism-spinner prism-spinner--20` in it. **In markup you write yourself, add `prism-spinner--20` to a loading button's spinner** (`<span class="prism-spinner prism-spinner--20"></span>`): the button centers its spinner by half of 20px, so a plain `prism-spinner` (24px) sits 2px right of and below the center.
- **Spinner progress** is new: `--progress` with an SVG ring, or `progress={40}` in the Phoenix and React components, which add `role="progressbar"` and the ARIA values. Name it with `aria-label` (or `aria-labelledby`). The track is light grey (`#eeeeee`), and white at 20% on the inverse spinner, so its white arc reads on a colored or dark background.
- **Buttons with an icon** also take their variant's disabled look now.
- **Tones color by variant.** A tone colors a primary button's background, and the text and border of the other variants: `.prism-button--primary.prism-button--danger`, `.prism-button--secondary.prism-button--danger`. A tone class without a variant class no longer colors anything. `--neutral` (dark grey) and `--highlight` (yellow) are new tones, and `--soft` and `--icon` new variants.
- **Plain and text buttons fit their text** unless they have `prism-button--padded` (15px top and bottom, 16px at the sides, as tall as a primary button). Without it, a plain button is as in 0.1.7 (4px top and bottom, none at the sides); a text button keeps 0.1.7's label button's 1px top and bottom but has no padding at the sides (it had 16px). The Phoenix and React components add `--padded` by default (`padded={false}` leaves it off).
- **The icon's side.** The Phoenix and React components put the icon before the label by default now (at its start), and after it with `icon_position={:end}` / `iconPosition="end"`; they used to put it after the label. In plain HTML, the order of the elements is the side.
- **Two classes beat one utility.** These rules are two classes together, which is more specific than one Tailwind utility, so a utility on such a button no longer wins as it did on 0.1.7's single classes; use Tailwind's important modifier (`!px-4`, `!text-grey1`) or your own CSS for it:
  - a button with an icon (`.prism-button--primary.prism-button--with-icon`): its padding and gap, where 0.1.7's `prism-btn-primary-icon` was one class;
  - a tone (`.prism-button--secondary.prism-button--danger`): its text, border and background colors, where 0.1.7's `prism-btn-danger` was one class;
  - `--padded` with a variant (`.prism-button--text.prism-button--padded`): its padding, so a padding utility on a padded plain or text button doesn't win either.
- `prism-max-lines-*` and `prism-text-shadow*` (in `css/base.css`) keep their names.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
