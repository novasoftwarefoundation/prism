# @novasoftwarefoundation/prism

A Tailwind-based UI framework for scientific software.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

## Features

- **Brand-neutral design** - Decoupled from specific branding for maximum third-party adoption
- **Hybrid approach** - Both Tailwind preset (for customization) and ready-made component classes
- **Variable fonts** - Uses Nunito and Nunito Sans variable fonts for optimal typography
- **Easy to adopt** - Drop-in CSS classes for common components

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

<!-- A button with an icon: the icon part, and --with-icon for its spacing -->
<button class="prism-button prism-button--primary prism-button--with-icon">
  <img class="prism-button__icon" src="add.svg" alt="" />
  <span class="prism-button__label">Add</span>
</button>

<!-- A loading button: the spinner shows only while --loading is set -->
<button class="prism-button prism-button--primary prism-button--loading">
  <span class="prism-button__label">Save</span>
  <span class="prism-spinner prism-spinner--inverse"></span>
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
<span class="prism-spinner prism-spinner--small prism-spinner--accent"></span>

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
| `prism-button--plain` | Text only, no padding or background |
| `prism-button--link` | Looks like a text link |
| `prism-button--text` | Brand-colored text, minimal styling |
| `prism-button--with-icon` | Spacing for a button with an icon (with `--primary`, `--secondary` or `--plain`) |
| `prism-button--success`, `--warning`, `--danger` | Tones, with a variant |
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
| `prism-spinner--small` | Small spinner (16px) |
| `prism-spinner--large` | Large spinner (32px) |
| `prism-spinner--accent` | Accent colored |
| `prism-spinner--inverse` | White, for colored backgrounds |

The spinner is an empty element drawn with `images/spinner.svg` (in this package) as a mask over its text color, so a text color utility colors it too.

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

0.2.0 renames every component class to the names design systems share; no old class is kept. Replace each 0.1.7 class with its 0.2.0 class:

| 0.1.7 class | 0.2.0 class |
| --- | --- |
| `prism-btn` | `prism-button` |
| `prism-btn-content` | `prism-button__label` |
| `prism-btn-primary` | `prism-button--primary` |
| `prism-btn-secondary` | `prism-button--secondary` |
| `prism-btn-plain` | `prism-button--plain` |
| `prism-btn-link` | `prism-button--link` |
| `prism-btn-label` | `prism-button--text` |
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
| `prism-spinner-sm` | `prism-spinner--small` |
| `prism-spinner-lg` | `prism-spinner--large` |
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

- **Spinner.** It is no longer a tinted image: use an empty element (`<span class="prism-spinner"></span>`, not an `<img>`). It is drawn with this package's `images/spinner.svg` as a mask over its text color, so CSS that drew it as a mask in an app can go. In a button it shows only while the button has `prism-button--loading`.
- **Buttons with an icon** also take their variant's disabled look now.
- `prism-max-lines-*` and `prism-text-shadow*` (in `css/base.css`) keep their names.

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
