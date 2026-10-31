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

```html
<!-- Buttons -->
<button class="prism-btn prism-btn-primary">Primary Button</button>
<button class="prism-btn prism-btn-secondary">Secondary Button</button>
<button class="prism-btn prism-btn-plain">Plain Button</button>

<!-- Inputs -->
<input type="text" class="prism-input" placeholder="Enter text" />
<textarea class="prism-textarea" placeholder="Enter description"></textarea>

<!-- Radio buttons -->
<div class="prism-radio-group">
  <label class="prism-radio-label">
    <input type="radio" name="option" class="prism-radio" />
    <span class="prism-radio-text">Option 1</span>
  </label>
  <label class="prism-radio-label">
    <input type="radio" name="option" class="prism-radio" />
    <span class="prism-radio-text">Option 2</span>
  </label>
</div>

<!-- Dropdown -->
<div class="prism-dropdown">
  <input type="text" class="prism-dropdown-input" value="Select option" />
  <div class="prism-dropdown-options">
    <div class="prism-dropdown-option">Option 1</div>
    <div class="prism-dropdown-option">Option 2</div>
  </div>
</div>

<!-- Spinner -->
<div class="prism-spinner"></div>

<!-- Tags / Badges -->
<span class="prism-tag prism-tag-primary">
  <span class="prism-tag-inner">New</span>
</span>
<span class="prism-tag prism-tag-success">
  <span class="prism-tag-inner">Complete</span>
</span>

<!-- Alert Banners -->
<div class="prism-alert prism-alert-info">Information message</div>
<div class="prism-alert prism-alert-success">Success message</div>
<div class="prism-alert prism-alert-warning">Warning message</div>
<div class="prism-alert prism-alert-error">Error message</div>

<!-- Number Icons (Step Indicators) -->
<span class="prism-number-icon prism-number-icon-completed">1</span>
<span class="prism-number-icon prism-number-icon-active">2</span>
<span class="prism-number-icon prism-number-icon-inactive">3</span>
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

| Class                     | Description                        |
| ------------------------- | ---------------------------------- |
| `prism-btn`               | Base button (required)             |
| `prism-btn-primary`       | Filled primary button              |
| `prism-btn-secondary`     | Outlined button                    |
| `prism-btn-plain`         | Text-only button                   |
| `prism-btn-link`          | Link-style button                  |
| `prism-btn-primary-icon`  | Primary button with icon           |
| `prism-btn-secondary-icon`| Secondary button with icon         |

### Inputs

| Class                | Description             |
| -------------------- | ----------------------- |
| `prism-input`        | Standard text input     |
| `prism-input-error`  | Input with error state  |
| `prism-textarea`     | Multi-line text input   |
| `prism-label`        | Form label              |
| `prism-label-error`  | Error message text      |

### Radio Buttons

| Class               | Description              |
| ------------------- | ------------------------ |
| `prism-radio-group` | Container for radios     |
| `prism-radio-label` | Label wrapper            |
| `prism-radio`       | Radio input              |
| `prism-radio-text`  | Radio label text         |

### Dropdown

| Class                   | Description            |
| ----------------------- | ---------------------- |
| `prism-dropdown`        | Container              |
| `prism-dropdown-input`  | Trigger input          |
| `prism-dropdown-options`| Options container      |
| `prism-dropdown-option` | Individual option      |

### Spinner

| Class                 | Description           |
| --------------------- | --------------------- |
| `prism-spinner`       | Base spinner (24px)   |
| `prism-spinner-sm`    | Small spinner (16px)  |
| `prism-spinner-lg`    | Large spinner (32px)  |
| `prism-spinner-white` | White colored         |
| `prism-spinner-primary`| Primary colored      |

### Tags / Badges

| Class                | Description                    |
| -------------------- | ------------------------------ |
| `prism-tag`          | Base tag container             |
| `prism-tag-inner`    | Inner content with styling     |
| `prism-tag-primary`  | Primary colored tag            |
| `prism-tag-success`  | Success/green colored tag      |
| `prism-tag-warning`  | Warning/orange colored tag     |
| `prism-tag-error`    | Error/red colored tag          |
| `prism-tag-danger`   | Alias for error                |
| `prism-tag-secondary`| Grey/neutral colored tag       |

### Alert Banners

| Class                 | Description                   |
| --------------------- | ----------------------------- |
| `prism-alert`         | Base alert banner             |
| `prism-alert-info`    | Info/primary colored alert    |
| `prism-alert-success` | Success/green colored alert   |
| `prism-alert-warning` | Warning/orange colored alert  |
| `prism-alert-error`   | Error/red colored alert       |

### Number Icons (Step Indicators)

| Class                        | Description                    |
| ---------------------------- | ------------------------------ |
| `prism-number-icon`          | Base circular number badge     |
| `prism-number-icon-inactive` | Grey/inactive state            |
| `prism-number-icon-active`   | Primary/current step state     |
| `prism-number-icon-completed`| Green/completed state          |

## License

MIT - See LICENSE file for details.

Fonts are licensed under the SIL Open Font License (OFL).
