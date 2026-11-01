# Prism for SwiftUI

Prism's design tokens and components for iOS, generated from Prism's design: the same colors, type, spacing and component looks as `@novasoftwarefoundation/prism` on the web.

Part of the [Nova Software Foundation](https://novasf.org) - open source software for science.

This package is generated in [novasoftwarefoundation/prism](https://github.com/novasoftwarefoundation/prism) (`targets/swift/`) and copied here at each release, with the same version as the npm packages. Don't edit it here: change the design in Prism and regenerate.

## Installation

Swift Package Manager, iOS 26 or later:

```swift
.package(url: "https://github.com/novasoftwarefoundation/prism-swift.git", exact: "0.2.0")
```

In Xcode: File > Add Package Dependencies, with the same URL, and add the `Prism` library to the app's target.

## Use the components

The components are look only: what a control does stays with SwiftUI's own control and the app. Each takes SwiftUI's own form for its kind.

```swift
import Prism
import SwiftUI

// A ButtonStyle: the action stays with the Button.
Button("Save", action: save)
    .buttonStyle(.prism(.primary, tone: .danger, loading: saving))

Button(action: next) { Label("Next", systemImage: "arrow.right") }
    .buttonStyle(.prism(.plain, padded: false, icon: .end))

// A ProgressViewStyle: without a value it turns, with one it shows it.
ProgressView().progressViewStyle(.prism(.accent, size: .size20))
ProgressView(value: upload.fraction).progressViewStyle(.prism(.accent, size: .size32))

// A ToggleStyle.
Toggle("Remember me", isOn: $remember).toggleStyle(.prism())

// A modifier on a TextField or TextEditor; the app gives focused and invalid.
PrismField(label: Text("Email"), errorMessage: error.map(Text.init)) {
    TextField("", text: $email, prompt: PrismTextFieldModifier.prompt(Text("name@example.org")))
        .focused($emailFocused)
        .prismTextField(focused: emailFocused, invalid: error != nil)
}

// A view each for the others.
PrismTag(tone: .success) { Text("Done") }
PrismMessageBar(tone: .warning) { Text("Your session ends in 5 minutes") }
PrismStepIndicator(status: .current) { Text("2") }
PrismRadioGroup {
    PrismRadio(checked: choice == .yes) { Text("Yes") }
    PrismRadio(checked: choice == .no) { Text("No") }
}
PrismSelect(icon: Image(systemName: "chevron.down")) {
    Picker("Country", selection: $country) { ... }
} label: {
    Text(country.name)
}
```

| Component | Swift |
| --- | --- |
| Button | `PrismButtonStyle`, `.buttonStyle(.prism(…))` |
| Spinner | `PrismSpinnerStyle`, `.progressViewStyle(.prism(…))` |
| Checkbox | `PrismCheckboxStyle`, `.toggleStyle(.prism(…))` |
| Text field, text area | `.prismTextField(…)` on a `TextField`, `.prismTextArea(…)` on a `TextEditor` |
| Field | `PrismField(label:errorMessage:) { control }` |
| Radio group, radio | `PrismRadioGroup { … }`, `PrismRadio(checked:) { label }` |
| Select | `PrismSelect { menu items } label: { … }`, on a `Menu` |
| Tag, message bar, step indicator | `PrismTag(tone:)`, `PrismMessageBar(tone:)`, `PrismStepIndicator(status:)` |

- **Variants** are enums of the design's values (`PrismButtonVariant.primary`, `PrismButtonTone.danger`, `PrismSpinnerSize.size16`), with the design's defaults: a button's tone is `.accent`, a spinner's size `.size24`, a tag's tone `.accent`, a message bar's `.info`, a step indicator's `.incomplete`. A button's variant and a spinner's color have none.
- **States SwiftUI knows come from SwiftUI:** pressed from the button, checked from the toggle, disabled from `.disabled(_:)`, hovered from the pointer. The app gives the others: `loading`, `invalid`, a text field's `focused` (from its `@FocusState`), a radio's `checked`.
- **A button with an icon** gets `icon: .start` or `icon: .end` and a `Label` as its label; the icon goes at that side of the title, and the button takes its look with an icon.
- **A spinner** keeps the `ProgressView`'s label for VoiceOver: `ProgressView("Uploading", value: 0.4)`.
- **A select's list** is the system's menu. Its looks are in `PrismSelectLooks().listbox` and `.option`, for an app that draws its own list.
- **Each component's looks** are data too: `PrismButtonLooks(.primary, pressed: true).root` is the `PrismLook` the style draws, for a view of the app's own. `.prismText(_:)`, `.prismBox(_:)` and `.prismLook(_:)` draw a look on any view.

## Tokens

```swift
Prism.Colors.primary          // Color
Prism.Typography.title4       // PrismTypography: .font, .uiFont(), Dynamic Type
Prism.Spacing.px10            // CGFloat
Prism.Radii.default           // PrismRadius
Prism.Shadows.prismCard       // PrismShadow
```

Lengths are points. Type follows Dynamic Type: each typography scales as the text style whose default size is the closest below its own (text up to 20 pt as body text, larger text as a title), and its line height with it. A box that holds text (a text field, a select, a message bar, a step indicator) grows with it, so the largest text sizes cut nothing off. The fonts are the system font (SF Pro) for now; the package bundles no fonts.

## License

MIT - See LICENSE file for details.
