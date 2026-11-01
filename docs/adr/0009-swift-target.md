# 0009: The Swift target: tokens and components in SwiftUI's own forms

Status: proposed, 2026-11-01

## Context

[ADR 0001](0001-design-format.md) planned a Swift target of values only: the tokens and one resolved style per component, with the views hand-written in each app. An iOS app that uses Prism today does exactly that: it copies Prism's colors, type and radius by hand into a file of its own, and writes the button's pressed, disabled and loading looks, the spinner and the input's frame again in SwiftUI. That is the drift ADR 0001 rejects ("Tokens only, components hand-written per platform"): every app would write the pressed, disabled and loading rules again.

SwiftUI has its own forms for a control's look. A `ButtonStyle`, a `ProgressViewStyle` and a `ToggleStyle` give the look of a `Button`, a `ProgressView` and a `Toggle` while the control keeps its action, which is Prism's "look only" in SwiftUI's terms. `TextFieldStyle` and `PickerStyle` have only underscored requirements, so they are no public extension point. Delivery was decided before this step (Flux 10462845695): Prism's Swift code is a package in its own repository, `prism-swift`.

## Decision

1. **A file target, `swift`.** `Prism.Generator.Swift` writes `targets/swift/`: `Package.swift`, and in `Sources/Prism/` the tokens (`Tokens.swift`), the types a look is made of (`Look.swift`) and one file per component. The files are committed, carry the `Prism.Generator.Header` line (`//`, also above `// swift-tools-version`), `mix prism.gen --check` covers them, and they are reviewed in Prism's pull requests, as every other target. The design names the package: `swift module: "Prism"` in `Prism.Design.Tokens`, the module and the prefix of its types (`PrismButtonStyle`, `Prism.Colors`). The package is `swift-tools-version: 6.2`, `.iOS(.v26)`, one library `Prism`. `README.md`, `LICENSE` and `.gitignore` in `targets/swift/` are hand-written.

2. **The tokens and all twelve components, each in SwiftUI's own form** (`Prism.Generator.Swift.Components`):

   | Component | Swift |
   |---|---|
   | `button` | `PrismButtonStyle: ButtonStyle`, `.buttonStyle(.prism(.primary, tone: .danger, loading: saving))` |
   | `spinner` | `PrismSpinnerStyle: ProgressViewStyle`, `.progressViewStyle(.prism(.accent, size: .size20))` |
   | `checkbox` | `PrismCheckboxStyle: ToggleStyle`, `.toggleStyle(.prism())` |
   | `text_field`, `text_area` | a `ViewModifier`: `.prismTextField(focused:invalid:)` on a `TextField`, `.prismTextArea()` on a `TextEditor` |
   | `select` | `PrismSelect`, a view on `Menu` |
   | `field`, `radio_group`, `radio`, `tag`, `message_bar`, `step_indicator` | a view each: `PrismTag(tone: .success) { Text("Done") }` |

   The target must know every component of the design (ADR 0001, decision 3.2), so it knows all twelve, not only those an app uses today. Like the web target, it knows them and their parts by name, and fails generation for one it doesn't know.

3. **The API, by the same rules as the Phoenix and React components:**
   - **Each axis is an enum** of the design's values (`PrismButtonVariant`, `PrismButtonTone`, `PrismSpinnerSize`), with the design's default; a default without a look of its own is a case too (`.accent`), an alias a static property. A variant named by a number has its axis's name in front (`.size16`, [ADR 0007](0007-spinner-sizes-progress.md)). The `:variant` axis is the first argument, without a label; an axis without a default is optional.
   - **Flags and the states the app sets are parameters** (`padded`, `loading`, `invalid`, a text field's `focused`, a radio's `checked`), a value a `Double?` from 0 to 100.
   - **States SwiftUI knows come from SwiftUI:** pressed from `configuration.isPressed`, disabled from `@Environment(\.isEnabled)`, checked from the toggle, hovered from the pointer, and a spinner's progress from the `ProgressView`'s fraction.
   - **Parts:** a button's icon is `icon: .start` or `.end` (`nil` without one); the button then lays out a `Label`'s icon at that side, and has its look with an icon. `ButtonStyleConfiguration` doesn't say whether the label has an icon, so the app says it. A field's label and error message are `Text?`, a select's icon an `Image?`.

4. **Looks as data, laid over each other as on the web.** Each component has `PrismComponentLooks`: its own look and each part's for one choice of variants, flags, parts, values and states, as `PrismLook` values, which the style or view draws and an app can read for a view of its own. The generated code lays each node's look (with its `ios:` binding) over the others in the order the web's CSS makes them win (`Prism.Generator.Swift.Looks`): by the weight of the node's selector, then in the design's order. So iOS shows what the web shows where two looks set one property. A state the app sets (`invalid`, `selected`, `loading`) outweighs `pressed`, `hovered` and `focused` for the properties both set ([ADR 0008](0008-app-state-over-interaction.md)): where the web adds a selector one class heavier than the pointer's or focus's rule, the Swift code adds a layer of those properties that holds while both states do and weighs the same, so a variant's own look for the state stays above the component's. A focused invalid text field keeps its warning border, on iOS as on the web.

5. **Mechanics are the target's**, as the web's are in its CSS: the spinner draws its ring (a quarter of it, at a quarter's opacity around) and turns, and with a progress value a track and an arc from the top in the value's stroke; the checkbox draws its check mark; an inset shadow is drawn over the background and inside the border, as CSS draws it; a border is inside the box, so padding and size are CSS's border box; a select's list is the system's menu (its listbox and option looks are only in its looks), and its icon takes the text color around it, not the menu's tint; a spinner keeps the `ProgressView`'s label and value for VoiceOver; a text field's placeholder color is in `PrismTextFieldModifier.prompt(_:)`, since a modifier can't reach a `TextField`'s prompt. Lengths are points, rem times 16; a percentage is only a radius from 50% (a capsule) or a stroke. Sides are leading and trailing, so they follow the text's direction.

6. **Type and Dynamic Type.** Type comes only from the typography tokens and the components' typography pairs. A line is as high as the typography's line height, as on the web. Dynamic Type scales a size and its line height as the text style whose default size is the closest below it: text up to 20 pt as body text (body, callout, subheadline, footnote, caption, caption 2), larger text as a title (title 3, title 2, title, large title). That keeps the base styles an iOS app uses today for Prism's type, so nothing shifts: 28 pt scales as title, 20 and 18 pt as body, 16 pt as callout and 14 pt as footnote. A look with text scales its size and heights the same way, and its height is the least it takes, also where its parent offers less: at the largest text sizes a text field, a select, a message bar and a step indicator grow with their text instead of cutting it off. On the web a fixed height lets the text overflow; on iOS it would be clipped.

7. **Fonts.** Both families are `:system` on iOS ([ADR 0002](0002-prism-design.md), decision 4), so the package uses SF Pro and bundles no fonts. Whether iOS gets Nunito and Nunito Sans is not decided yet. The generator already supports it, so the change is the design's iOS binding (`ios: [name: "Nunito", faces: [[file: "Nunito-VariableFont_wght.woff2", …]]]`) and `swift fonts: "../targets/web/fonts", font_files: ["OFL.txt"]`: the target then copies the files into `Sources/Prism/Fonts/`, declares them as the package's resources, and registers them with CoreText the first time a typography needs one, so an app lists no fonts in its Info.plist.
   - **A copy kind of file in `mix prism.gen`.** A target may return `{:copy, source}` for a file: it is written byte for byte, with no header, and `--check` compares its bytes. A target names the folders it copies into (`copy_folders/1`; the Swift target's is `Sources/Prism/Fonts/`), also while it copies nothing, and they are the generator's: a copy replaces the file at its path (never a link or a folder), and any file there, not a link, that no target copies now is left over, removed by `mix prism.gen` and failed by `--check`. So a design that stops bundling its fonts leaves none behind. A copy folder, or a folder between it and the target's, that is a link fails the task, since it would copy into and remove from a folder outside the target.

8. **Delivery: a mirror in `prism-swift`, tagged with Prism's version.** `.github/swift-release.sh vX.Y.Z <clone>` first checks everything: Prism's tag is checked out and clean, and the clone is on a branch, clean, equal to its origin, and has the tag neither locally nor on origin. Then it mirrors the files the tag tracks in `targets/swift/` (`git archive`, so no ignored or untracked file ships) to the root of the clone (`rsync --delete`, keeping `.git`), commits them as "Prism vX.Y.Z (<commit>)", tags them `vX.Y.Z`, the npm packages' version, and pushes the branch and the tag in one atomic push. When the push fails, the clone is put back as it was, so the script runs again as it is. A pushed tag is never moved or deleted: a broken release is followed by a patch release. SwiftPM resolves `exact: "0.2.0"` to the tag `v0.2.0`. The README's Publish steps run it; it runs by hand, as the other publish steps do.

9. **Checks.** In `generator/`, two example designs' packages are reviewed fixtures (`generator/test/fixtures/swift/components/`, a component of every kind, and `…/design/`, a token of every kind), and Elixir tests cover the order of the looks, the names, the states, the values, the fonts and copies, and the errors. One macOS CI job builds Prism's package and both fixtures with `xcodebuild` for the iOS Simulator, a warning failing the build, with one exact Xcode the runner image has (26.6 on `macos-26`); the job fails when the image no longer has it. It also runs `design/test/swiftui/`, a test package that renders every component of Prism's on a simulator at the default and the largest text size, and fails when a box is smaller than its text or doesn't grow with it. `design/test/swift_test.exs` checks the committed files, the base text styles and the spinner. Nothing Prism-specific is in `generator/`; CI's check for it stays.

## Alternatives

| Option | Why not |
|---|---|
| Values only, views hand-written in each app (ADR 0001's plan) | Each app writes the pressed, disabled and loading rules again; that is the drift ADR 0001 rejects. |
| A view for every component, also the button (`PrismButton(action:)`) | A second action API beside SwiftUI's `Button`; a `ButtonStyle` keeps the action with SwiftUI and the look with Prism, as on the web. |
| A `TextFieldStyle` or `PickerStyle` | Their only requirements are underscored, so no public extension point. |
| Resolve each combination at generation time into a table | The button alone has thousands of combinations of variant, tone, flag, icon and states; laying the nodes' looks over each other at run time, in the web's order, keeps the code the size of the design. |
| States in a fixed order of their own (the app's states always last) | It would also put `invalid` over `disabled` and over a variant's own look; ADR 0008's rule is narrower, and iOS follows the web's. |
| Write into a `prism-swift` checkout directly from `mix prism.gen` | The Swift code would be outside Prism's review and `--check`. |
| A Dynamic Type base style per typography in the design (`ios: [text_style: …]`) | A rule gives the same styles for every typography without a setting per token. |

## Consequences

- An iOS app gets Prism's components from the design, with the same numbers as the web: it depends on `prism-swift` at the release's version and deletes its own copy of Prism's values.
- The package's version is Prism's: every release mirrors `targets/swift/` to `prism-swift` and tags it, after the npm packages.
- A new kind of component needs its SwiftUI form in `Prism.Generator.Swift.Components`; a new variant, part or state of a known component needs only the design.
- A focused invalid text field keeps its warning border, on iOS as on the web ([ADR 0008](0008-app-state-over-interaction.md)).
- Bundling Nunito and Nunito Sans later is a change to the design's iOS binding and its `swift` declaration, with no change to the generator.
