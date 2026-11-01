# 0008: A state the app sets outweighs the pointer and the focus

Status: proposed, 2026-11-01

## Context

Prism's text field has a warning border while it is `invalid`, a state the app sets, and a primary border while it is `focused` (a yellow one on the `inverse` field). On the web, `.prism-text-field:focus` is a class and a pseudo-class, which outweighs `.prism-text-field--invalid`, one class. So a focused invalid field shows the focus border, and the warning goes away just while someone corrects the value.

The owner decided that an invalid field keeps its warning border while it has focus, on the web and on iOS (Flux 10463738969). The format can't say this in the design: a state can't hold another state, so there is no look for "invalid and focused" to give ([ADR 0001](0001-design-format.md)). Which state wins has to be a rule of the format, which every target follows.

## Decision

1. **A state the app sets outweighs the pointer and the focus.** Where a state the app sets (`invalid`, `selected`, `loading`) and `pressed`, `hovered` or `focused` change the same property of the same element, the app's state wins. This holds property by property: the focused state's other properties still apply. The app's state says something about the value or the choice, and that stays true while someone points at the element or types in it.

2. **Only the pointer and the focus.** `disabled` and `checked` are not part of the rule. They aren't passing states of someone acting on the element, and whether `invalid` should outweigh `disabled` is a separate design question. No component in Prism's design has both change one property today.

3. **On the same element.** The rule covers a state the app sets on a component or on one of its parts. It holds against the pointer and focus states of every node drawn on that element:
   - for a component, its own states and those of its variants, its flags, and its looks with a part or with a variant;
   - for a part, its own states and each variant's change to it.

   A state the app sets inside a variant keeps the web's usual weights. Prism's design has none.

4. **On the web, one class heavier.** The app's state keeps its rule. That rule also gets the selector of each pointer or focus rule that changes one of its properties, with the state's class added:

   ```css
   .prism-text-field--invalid,
   .prism-text-field.prism-text-field--invalid:focus,
   .prism-text-field--inverse.prism-text-field--invalid:focus {
     border-color: #f28d15;
   }
   ```

   Each added selector is one class heavier than the browser's rule, so it wins wherever it stands in the file and whatever order the design gives the states. Only a rule that shares a property gets a selector, so the CSS changes only where the look changes. The Phoenix and React components set the same classes, so nothing changes in them.

5. **A native target lays the app's state over these states.** A target that draws looks as layers puts the layer of a state the app sets above the `pressed`, `hovered` and `focused` layers of the same element, for the properties both set. iOS then shows what the web shows.

In Prism's design, only the text field has both an invalid look and a focus look. The text area and the select have a focus look but no invalid look. If they get one, this rule covers them with no further change.

## Alternatives

| Option | Why not |
|---|---|
| Give the focused invalid look in the design (a state inside a state, or a `with_state` node) | The format has no way to combine states. A new node would need drawing in every target, and every field would have to repeat it for a rule that holds for all of them. |
| An option on a state that names the states it outweighs (`state :invalid, …, over: [:focused]`) | Each design would have to repeat it. Which state wins comes from what the states mean, and the format fixes that meaning. |
| A fixed order for all states (the later one in the format's list wins) | It would also put `invalid` over `disabled` and change the order of other states, such as pressed and disabled on a button. That changes more than the decision asks for. |
| Lower the weight of the browser's states with `:where()` | It changes the weight of every state rule, including those an app overrides with its own CSS. |
| `:not(.prism-text-field--invalid)` on the focus rules | It drops all of the focus look on an invalid field, not just the properties `invalid` sets. |
| Rely on the order in the file (invalid after focus) | A variant's focus rule comes later in the file (the inverse field's) and would still win. |

## Consequences

- A focused invalid text field keeps its warning border, on the inverse field too. In `css/components.css`, the invalid rule gets two more selectors. The golden diff (`design/test/golden/0.1.7.diff`) includes them.
- An app that styled a focused invalid field itself can drop that CSS.
- A native target ranks the layer of a state the app sets above the pointer and focus layers of the same element. A Swift target that ranks layers by the weight of the web's selectors does this through the added selectors' weight.
