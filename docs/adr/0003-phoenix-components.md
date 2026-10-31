# 0003: Phoenix components at compile time

Status: proposed, 2026-10-31

## Context

A design ([ADR 0001](0001-design-format.md)) reaches a platform through a target that writes files: the web target writes `components.css`. An Elixir app needs more than the CSS. It renders the markup, and today it types the class names by hand (`"prism-btn prism-btn-primary"`), so a renamed or removed class fails silently in the browser.

The design is Elixir code, and `__schema__/0` returns it as data. An Elixir app that depends on the design can therefore build its components while it compiles, the way `use Gettext.Backend`, `use Ecto.Repo` and `use Phoenix.Component` build code in the app's own module. Files would only be needed for a language that can't read the design.

## Decision

1. **A macro, no Elixir target and no generated files.** An app writes

   ```elixir
   defmodule MyAppWeb.Prism do
     use Prism.Generator.Phoenix, design: MyApp.Design
   end
   ```

   and the macro defines one function component per design component (`button/1`, `text_field/1`, …) in that module, with `attr` and `slot` declarations. It `use`s `Phoenix.Component` unless the module already does.
   - It reads the design's `__schema__/0` while the module compiles and `require`s the design: a compile-time dependency (`mix xref graph --label compile` shows the edge), so the module recompiles when the design changes. A new variant is there at once; a removed one makes Phoenix warn where the app still passes it.
   - A design component or part this target doesn't know fails the app's compilation at the `use` line, as the web target fails generation.

2. **Phoenix is an optional dependency of `generator/`** (`{:phoenix_live_view, "~> 1.1", optional: true}`). `Prism.Generator.Phoenix` and its renderer are wrapped in `if Code.ensure_loaded?(Phoenix.Component)`, so they exist only in an app that has LiveView. The design (`design/`) stays free of Phoenix: Swift, Kotlin and the CSS read the same design. `design/` takes LiveView as a test-only dependency, for a test that renders Prism's components. CI compiles the generator with `mix compile --no-optional-deps` before fetching its dependencies, so the optional dependency stays optional.

3. **One class derivation.** `Prism.Generator.Web.Classes` turns design names into class names (component, part, modifier, a part's state) and knows which elements are form controls, whose states are pseudo-classes. The web target writes its selectors with it, and the Phoenix components render their classes with it, so the classes a component renders are the classes its CSS styles. Tests render every component, axis value and state, and check every class against the CSS the web target generates from the same design: in `generator/` on a neutral example design with one component of every kind, in `design/` on Prism's design and its committed `components.css`. The only classes without a rule are those of a part or component without a look of its own (Prism's button icon, its field), which the components render as hooks for the app.

4. **Attributes.**
   - Each **axis** (`variant`, each `variants` block) is an atom attribute with `values:` from the design, so Phoenix warns at compile time about an unknown value. Its values are the axis's variants and their aliases.
   - Each axis has the **design's default**. The format gets a `default:` option, on a `component` for its `:variant` axis and on a `variants` block, and `__schema__/0` carries it (`default` on the component, `default` on each axis). A default is one of the axis's variants (a tag's `:accent`, whose class it then adds), a name without a look of its own (a button's `:accent` tone, a spinner's `:medium` size: no class, but a value the app can pass), or none (the attribute adds no class until the app picks one). The schema checks that a default is a snake_case name, not an alias, and, when it is no variant, not another name of the component.
   - Each **state the app sets** is a boolean attribute. A state the CSS writes as a modifier class adds that class (`loading`, `invalid`, the radio row's `disabled`, on the component or on the part it belongs to). `disabled` and `checked` on a form control set the element's own attribute instead, which the CSS's pseudo-class reads; a disabled component also disables the form controls among its parts. The browser's states (`pressed`, `hovered`, `focused` on a form control) get no attribute.
   - `class` appends the app's classes after the component's own; `rest` takes the global attributes and the element's own (`type`, `name`, `value`, `href`, …).

5. **Parts, in the design's order.** The part that holds the content is the inner block (a button's or a tag's `label`, the select's `field`); a part such as an icon is a slot of its own name (`<:icon>`), whose presence adds the look with that part (`--with-icon`); a part that is another component (the button's spinner) is rendered while the component is `loading`, when it has a loading state, and always otherwise. A slot takes any attribute for its part's element (`class`, `for`, `phx-click`), and a select's `<:option>` takes `selected`. Part nesting stays out of the format: the select's options sitting in its listbox is this target's mechanics, keyed on the part names, as the web target's mechanics are.

6. **Elements per component, from what the CSS expects.** Like the web target, this target knows its components by name: a text field is an `<input>`, a text area a `<textarea>`, a radio a `<label>` around its `<input type="radio">` control (which gets `rest`), a spinner an empty `<span>`, a select a `<div>` with a `<button>` field and a `<ul role="listbox">`. The button's element is the app's choice, `as` (default `"button"`), through `Phoenix.Component.dynamic_tag`: an app that wraps the look in its own action renders it as a `<div>` or `<span>`. The full table is in the module's documentation.

7. **Look only.** A component renders markup and classes, never behaviour. In the main consumer app, the button becomes the look inside its own action wrapper, which stays in the app. A translation of that app's own names is not part of this decision.

## Alternatives

| Option | Why not |
|---|---|
| An Elixir target that writes `.ex` files | Files to commit, regenerate and keep in step with the CSS, for a language that can read the design directly. |
| The macro in the design (`design/` depends on Phoenix) | The design would depend on a web framework that Swift, Kotlin and the CSS don't need. |
| String values (`variant="primary"`) | Phoenix's own core components use them, but the axis names are atoms in the design, and atoms read the same in the design, the schema and the app. |
| One generic renderer with no per-component knowledge | The CSS expects specific elements (an `<input>` for a text field, a `<label>` around a radio), so the markup needs the same names the web mechanics are keyed on. |
| Part nesting in the format (`part :option, within: :listbox`) | Only the select needs it, and the target already knows the select's parts by name. A native target that needs it can add it then. |
| A default that is always a variant | A button's accent tone and a spinner's medium size are the component's own look, with no class; making them variants would add classes and rules to the CSS. |

## Consequences

- An app gets its class names, values and markup from the design: a misspelled variant warns at compile time, and the classes can't drift from the CSS of the same version.
- The app must take the CSS and the design at the same version, or a class can be missing from the CSS. How the main consumer app takes both from one pin is decided when it adopts the components.
- The renderer uses `Phoenix.Component.Declarative.def/2`, the `def` that `use Phoenix.Component` imports, so the generated functions are components. CI tests the locked LiveView (1.2); the generator's tests also pass on 1.1.13.
- A new kind of component needs its element and parts here as well as its mechanics in the web target; a new variant, part or state of a known component needs only the design.
