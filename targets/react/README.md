# @novasoftwarefoundation/prism-react

Prism's components for React, generated from Prism's design: one component per design component, with props typed from the design.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

The components render the look only: their element, classes and parts. What a component does stays in the app: `onClick` and the other DOM props go on the element.

An iOS app gets the same components in SwiftUI from the Swift package [`prism-swift`](https://github.com/novasoftwarefoundation/prism-swift), at the same version.

## Installation

```bash
npm install @novasoftwarefoundation/prism-react @novasoftwarefoundation/prism
```

The CSS comes from [`@novasoftwarefoundation/prism`](https://www.npmjs.com/package/@novasoftwarefoundation/prism), a peer dependency at the same version: this package ships no CSS of its own. React 18 and 19 work.

## Import the CSS

Import Prism's CSS once, in the app's main stylesheet:

```css
@import "@novasoftwarefoundation/prism/css/base.css";
@import "@novasoftwarefoundation/prism/css/components.css";
```

With Tailwind, also add Prism's preset; see the CSS package's README.

## Use the components

```tsx
import { Button, Field, Tag, TextField } from "@novasoftwarefoundation/prism-react";

export function Profile({ saving, errors, onSave }) {
  return (
    <form>
      <Field label="Email" labelProps={{ htmlFor: "email" }} errorMessage={errors[0]}>
        <TextField id="email" name="email" invalid={errors.length > 0} />
      </Field>

      <Button variant="primary" tone="danger" loading={saving} icon={<CheckIcon />} onClick={onSave}>
        Save
      </Button>

      <Tag tone="success">Done</Tag>
    </form>
  );
}
```

- **Axes** (`variant`, `tone`, `size`, `status`) are props typed from the design, so TypeScript rejects `variant="primray"`; from untyped JavaScript, a value the axis doesn't have (`size={20}`, `size="16"`) throws when it renders. Without one, an axis has the design's default: a button's tone is `"accent"` and a spinner's size `24` (no class), a tag's tone is `"accent"`, a message bar's `"info"`, a step indicator's `"incomplete"`. A button's `variant` and a spinner's color have no default.
- **Buttons**: `variant` is `"primary"`, `"secondary"`, `"plain"`, `"link"`, `"text"`, `"soft"` (the tone's light color behind its color) or `"icon"` (an icon only, 24×24; give it an `aria-label`). A `tone` (`"success"`, `"warning"`, `"danger"`, `"neutral"`, `"highlight"`) colors a primary button's background and the others' text and border; `"soft"` has no look with `"neutral"` or `"highlight"`. `padded` (default `true`) makes a plain or text button as tall as a primary one beside it; `padded={false}` fits it to its text.
- **Spinners**: `size` is a number, its px: `16`, `20`, `24` (the default) or `32`. `progress`, a number from 0 to 100 (clamped; `null` or `NaN` is none, and anything else that isn't a number, such as `"40"`, throws when it renders), shows a light grey ring (white at 20% on the inverse spinner) with an arc in the spinner's color as long as the value, and adds `role="progressbar"` with the ARIA values; name it with `aria-label` (or `aria-labelledby`), as in `<Spinner progress={progress} aria-label="Uploading" />`. Without it, the spinner turns as it always does. A loading button's spinner is 20px.
- **States the app sets** are boolean props: `loading`, `invalid`, `disabled`, `checked`. On a form control, `disabled` and `checked` set the element's own attribute; elsewhere a state adds its class (`prism-radio--disabled`). The browser's states (pressed, hovered, focused) need nothing.
- **Parts** follow the design's order: `children` is the label, `icon` the icon (with it, the button gets `prism-button--with-icon`), and the spinner shows while `loading`. The icon goes at the start of the label, or at its end with `iconPosition="end"`; start and end follow the text's direction. Any other value throws when it renders, as an `as` the button doesn't know does. A part's element takes attributes through `<part>Props` (`labelProps`, `iconProps`). A select's options are `options`, each the attributes of its `<li>` plus `selected`.
- **Adjusting**: `className` adds the app's classes after the component's own, the other props go on the element (on a radio, on its `<input>`), and so does the ref. A button's element is `as`: `"button"` by default, or `"a"`, `"span"` or `"div"` when the app wraps it in its own action.

The components have no global side effects and need no context provider.

## Generated

The components are generated from Prism's design by `mix prism.gen`, with the same class names as the CSS, and built with `tsc` into ES modules and type declarations. To change one, change the design; see the [repository](https://github.com/novasoftwarefoundation/prism).

## License

MIT - See LICENSE file for details.
