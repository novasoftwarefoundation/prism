# 0008: A state the app sets outweighs the pointer and the focus

Status: proposed, 2026-11-01

## Context

Prism's text field has a warning border while it is `invalid`, a state the app sets, and a primary border while it is `focused` (a yellow one on the `inverse` field). On the web, `.prism-text-field:focus` is a class and a pseudo-class, which outweighs `.prism-text-field--invalid`, one class. So a focused invalid field shows the focus border, and the warning goes away just while someone corrects the value.

The owner decided that an invalid field keeps its warning border while it has focus, on the web and on iOS (Flux 10463738969). The format can't say this in the design: a state can't hold another state, so there is no look for "invalid and focused" to give ([ADR 0001](0001-design-format.md)). Which state wins has to be a rule of the format, which every target follows.

## Decision

1. **A state the app sets outweighs the pointer and the focus.** The states the app sets are `invalid`, `selected` and `loading`, picked by name. Where one of them and `pressed`, `hovered` or `focused` change the same property, the app's state wins. The rule holds property by property: the focused state's other properties still apply. The app's state says something about the value or the choice, and that stays true while someone points at the element or types in it.

2. **Only the pointer and the focus.** `disabled` and `checked` are not part of the rule, also on an element that isn't a form control, where the web writes them as classes. They aren't passing states of someone acting on the element, and whether `invalid` should outweigh `disabled` is a separate design question. `pressed`, `hovered` and `focused` don't outweigh each other either. No component in Prism's design has both change one property today.

3. **On the element and on each part.** The rule compares the properties a state changes on its own element with those the pointer or focus changes there. It compares a state's change to a part with the pointer's or focus's change to that same part, whether or not they share a property on the element itself.

4. **Against every node that holds with the state.** The rule holds against the pointer and focus states of the nodes on the same element that hold whenever the state's node holds, or within it:
   - for a component's own state, its own states and those of its variants, its flags, and its looks with a part or with a variant;
   - for a part's own state, its own states and each variant's change to the part;
   - for a state in a variant (or a flag, or a look), the component's or the part's own states, the variant's, and those of the nodes within the variant.

   A property that a node within it sets in a look of its own for the same state is left to that look, property by property: only those properties are left out of the comparison, not the node. A variant's own invalid look then outweighs both the focus and the component's invalid look, as it does without the focus, and for the properties it doesn't set, the component's invalid look still outweighs the variant's focus. A variant whose own invalid look sets only the background, and whose focus look sets the border, keeps the component's warning border on a focused invalid field.

5. **On the web, at least one class heavier.** The app's state keeps its rule. That rule also gets, for each pointer or focus rule that changes one of its properties, the classes of both selectors together, for each element in the selector:

   ```css
   .prism-text-field--invalid,
   .prism-text-field.prism-text-field--invalid:focus,
   .prism-text-field--inverse.prism-text-field--invalid:focus {
     border-color: #f28d15;
   }
   ```

   Each added selector is at least one class heavier than the browser's rule, so it wins wherever it stands in the file and whatever order the design gives the states. It wins only for the properties both rules change, less those left to a node's own look (decision 4): when those are all of the state's properties, it goes on the state's rule, as above; otherwise it gets a rule of its own after it, with only those properties, so it outweighs no other rule for the rest. A variant's own look for the state carries the variant's class too (`.prism-text-field.prism-text-field--inverse.prism-text-field--invalid:focus`), so it outweighs the component's. A combination that can't hold, such as two variants of one axis or two names of one variant, gets no selector. A state's change to a part gets the same for the part: for a tag whose selected and hovered looks both color its label, `.prism-tag.prism-tag--selected:hover .prism-tag__label`. Only a rule that shares a property gets a selector, so the CSS changes only where the look changes. The Phoenix and React components set the same classes, so nothing changes in them.

6. **A native target lays the app's state over these states.** A target that draws looks as layers puts the layer of a state the app sets above the `pressed`, `hovered` and `focused` layers it is compared with, for the properties both set. A node's own look for the state stays above the component's look for it. iOS then shows what the web shows.

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
- An app that styled a focused invalid field itself can drop that CSS. On an invalid field, the added selectors now beat an app's own `:focus` border: a Tailwind `focus:border-*` utility, or a rule of one class and `:focus` such as `.prism-text-field--invalid:focus`. An app that wants another color there uses the important modifier (`focus:!border-…`) or a rule at least as heavy (`.prism-text-field.prism-text-field--invalid:focus`), after Prism's CSS.
- A native target ranks the layer of a state the app sets above the pointer and focus layers it is compared with, and a node's own look for the state above the component's. A target that ranks layers by the weight of the web's selectors has to rank them as the added selectors weigh.
