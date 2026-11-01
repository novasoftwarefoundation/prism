# 0004: React components, generated

Status: proposed, 2026-10-31

## Context

A React app that uses Prism builds its components from the CSS classes by hand, the way an Elixir app did before [ADR 0003](0003-phoenix-components.md): it types `prism-button prism-button--primary` itself, or copies Prism's values into its own styles. A renamed class then fails silently in the browser, and a copied value drifts.

An Elixir app reads the design while it compiles. A React app can't: its toolchain doesn't run Elixir. So React needs a target that writes files ([ADR 0001](0001-design-format.md), decision 7), as the web target writes the CSS.

Later, a website built in a visual site builder will use the same components as code components: React rendered in a Shadow DOM, with `components.css` loaded as a global stylesheet. That integration is not part of this decision, but the components must not break there.

## Decision

1. **A file target, `react`.** `Prism.Generator.React` writes `targets/react/src/`: one TSX file per design component (`Button.tsx`, `TextField.tsx`, …), an `index.ts` that exports them all, and `helpers.ts` (joining class names, and whether the app gave a part content). Each file starts with the `Prism.Generator.Header` line naming the design file. The generated files are committed and `mix prism.gen --check` covers them, as it covers the web files. The generator needs no Node: the target writes text, and the package's own toolchain builds it.

2. **The same markup as the Phoenix components, from one derivation.** `Prism.Generator.Web.Elements` turns the design's `__schema__/0` into what the web's components render: per component its element, its parts in the design's order and what each one is, the class each axis value adds, and what each state the app sets does (a class, or the element's own attribute). It names every class with `Prism.Generator.Web.Classes`, as the CSS does. It was the first half of `Prism.Generator.Phoenix`; it moved out unchanged and needs no Phoenix, so the Phoenix components render from it at compile time and the React target writes from it.
   - **The class names are literals in the generated code**: a `Record` per axis from value to class, and the state, part and look-with-a-part classes as strings. TypeScript only joins them. There is no class logic in TypeScript that could drift, so the CSS, the Phoenix components and the React components come from one function.

3. **Props, by the same rules as the Phoenix attributes:**
   - Each **axis** (`variant`, each `variants` block) is a prop typed as a string union of the axis's values: its variants and their aliases, and its default when that is a name without a look of its own. TypeScript rejects any other value, and the component throws on one when it renders (from code TypeScript doesn't check, such as a size the design no longer has), as Phoenix's renderer does; an axis without a default also takes `null` and `undefined`, as Phoenix's takes `nil`. It has the design's default: one of the variants (whose class it adds), a name without a class (a button's `"accent"` tone), or none (no class until the app picks one). The values are the design's names as they are (`"primary"`), or numbers for an axis named by numbers (`16 | 20 | 24 | 32`, [ADR 0007](0007-spinner-sizes-progress.md)).
   - Each **value** (a spinner's `progress`, ADR 0007) is a `number | null` prop; `null`, `NaN` or no prop is no value, as Phoenix's `nil`; anything else that isn't a number (`"40"`) throws when it renders, as Phoenix raises. While the app gives a finite number, clamped to 0..100, the element gets the value's class, `role="progressbar"` with the ARIA values, and what the value draws (the spinner's ring).
   - Each **state the app sets** is a boolean prop. A state the CSS writes as a modifier class adds that class (`loading`, `invalid`, the radio row's `disabled`, on the component or the part it belongs to). `disabled` and `checked` on a form control set the element's own attribute instead, also on a part that is a form control (a radio's input, a select's field), and a disabled component disables the form controls among its parts. A state the app doesn't set is `undefined`, not `false`, so a checkbox without `checked` stays uncontrolled.
   - **Parts, in the design's order.** The part that holds the content gets `children` (a button's or a tag's label, a select's field). A part such as an icon is a `ReactNode` prop of its own name, camelCased (`icon`, `errorMessage`), with `<part>Props` for the attributes of its element (`labelProps={{ htmlFor: "email" }}`); while it is there, its look with a part adds `--with-<part>`. A part with `position:` in the design gets a `<part>Position` prop, `"start" | "end"` (`iconPosition`). A flag is a boolean prop with the design's default, adding its class as in Phoenix ([ADR 0006](0006-button-looks.md)). A part that is another component (the button's spinner) is rendered while the component is `loading`, when it has a loading state, and always otherwise. A list part's items (a select's options) are an array prop, `options`, each the attributes of the item's element plus a boolean per item state and `selected` (`aria-selected`).
   - A button's element is **`as`**, one of the elements `Prism.Generator.Web.Elements.as/0` lists (`button`, `a`, `span`, `div`), as in Phoenix. `ButtonProps` is a union with one member per element, so `as="a"` takes an anchor's props. Without `as`, a button refuses the attributes only the other elements have, typed `never` in its member: `<Button href="/x">` fails to compile, as Phoenix warns about it. Without that, TypeScript would accept it, because a union's excess-property check only refuses a prop that no member has. Any other `as` fails to compile, and fails at render time when it comes from outside.
   - **`className` appends** the app's classes after the component's own. The other props (`onClick`, `id`, `aria-*`, `data-*`, the element's own attributes) go on the element, and so does the ref (`forwardRef`), or on the form control of a component that has one (a radio's input; the row takes `className`).

4. **Look only, and nothing global.** A component renders markup and classes, never behaviour: what a button does stays in the app, through the props it passes. The components have no side effects at import (`"sideEffects": false`), read nothing from the document, and need no context provider, so they work wherever React renders them, a Shadow DOM included, given Prism's CSS.

5. **The package: `@novasoftwarefoundation/prism-react`**, published from `targets/react/`.
   - ES modules and `.d.ts` files in `dist/`, built from the generated TSX with `tsc` (`prepack` builds them, so `dist/` is not committed). Every build first empties `dist/`, so a file a removed component left there is never packed. It uses the automatic JSX runtime.
   - **No CSS of its own.** Its CSS is the web target's: `@novasoftwarefoundation/prism` is a peer dependency at exactly the same version, so an app can't pair the components with CSS of another version. The app imports `css/base.css` and `css/components.css` as before.
   - React is a peer dependency, `^18.0.0 || ^19.0.0`. CI type-checks and renders the components with both.
   - **One version.** The package has the design's version, like the CSS package ([ADR 0002](0002-prism-design.md), decision 7); a test checks the version and the peer dependency. The two packages are published together, the CSS first.

6. **Tests.**
   - In `generator/`, on the neutral example design with one component of every kind: the generated files are compared with reviewed fixtures (`generator/test/fixtures/react/src/`), and that fixture is a small package of its own whose `npm test` type-checks them (`tsc --noEmit`, with `// @ts-expect-error` lines: an unknown variant, tone or element, and a link's attribute on a button without `as`, must fail to compile) and renders every component with `react-dom/server`, checking its markup, its classes for each axis value and state, its parts and their order, the spinner while loading, native `disabled` and `checked`, and that every class is in the example's generated `components.css`. Elixir tests cover designs Prism's doesn't have and the errors.
   - In `design/`: the committed files have their headers, and the button's classes are in `components.css`. `targets/react` has its own `npm test`: it builds the package, type-checks it and renders every component against the `components.css` that `@novasoftwarefoundation/prism` ships.
   - CI runs both packages' tests on React 19 (the lockfiles') and 18 (a lockfile of its own per package, `test/react18/package-lock.json`, so React 18's dependencies are pinned too), type-checks them with TypeScript 7 and 5.9, and checks the file list `npm pack` would publish against `.github/npm-files-react.txt`.

## Alternatives

| Option | Why not |
|---|---|
| A hand-written React package that reads a generated class map | The rules (which state is a class and which an attribute, where the content goes, when a part shows) would be written again in TypeScript, and could drift from the Phoenix components. |
| Generate only the class names (a `classes.ts`) and leave the components to each app | Every app would write the same markup again, and the markup is part of what the CSS expects. |
| Ship the CSS in the React package too | Two copies of one stylesheet, which a bundler can import twice; a peer dependency at the same version keeps one. |
| Components without `forwardRef`, taking `ref` as a prop | Only React 19 passes `ref` as a prop; `forwardRef` works in 18 and 19. |
| Variant values in camelCase (`"extraLarge"`) | Two spellings of one name across targets; the design's names read the same in the design, the Phoenix atoms and the React strings. |
| Commit the built `dist/` | Two committed forms of one code; `tsc` builds it reproducibly when the package is packed. |

## Consequences

- A React app gets its markup and class names from the design: a misspelled variant fails to compile, and the classes can't drift from the CSS of the same version.
- A new kind of component needs its element and parts in `Prism.Generator.Web.Elements`, and they reach the Phoenix and the React components together, besides its mechanics in the web target's CSS. A new variant, part or state of a known component needs only the design.
- A release publishes two npm packages at one version, the CSS first.
- The generated code is typed with the button's types where its element is the app's choice: `ButtonProps` checks the app's props per element (a button without `as` refuses a link's `href`), and the component renders them on the element the app picked.
- A release also updates the React package's lockfiles (`npm install --package-lock-only`, then `.github/react18.sh --update` for React 18's, made from the bumped files, which it leaves as they are), which record the version and the peer; the version test checks them.
- No app switches to the package in this change; each one adopts it in its own change.
