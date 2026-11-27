# Prism for Jetpack Compose

Prism's design tokens and components for Android, generated from Prism's design: the same colors, type, spacing and component looks as `@novasoftwarefoundation/prism` on the web and `prism-swift` on iOS.

Part of the [Nova Software Foundation](https://novasoftwarefoundation.org/) - open source software for science.

This library is generated in [novasoftwarefoundation/prism](https://github.com/novasoftwarefoundation/prism) (`targets/kotlin/`) and published to Maven Central at each release, with the same version as the npm packages. Don't edit it: change the design in Prism and regenerate.

## Installation

From Maven Central, for an app on Kotlin 2.2 or later, minSdk 23 or later and compileSdk 37.1 (with the Android Gradle plugin 9), with Compose 1.13 and Material 3 1.5 (the Compose BOM 2026.11.01, which the library brings):

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

// build.gradle.kts
dependencies {
    implementation("org.novasoftwarefoundation:prism-compose:0.8.0")
}
```

The files are signed with the key `24270AF8F9E30AD3EDF7A0B0F9156907F9CCAC8D` (on `keyserver.ubuntu.com`).

## Use the components

The components are look only: what a control does stays with Compose and the app. Each takes Compose's own form for its kind, with its parameters in Compose's order: what it can't do without, `modifier`, the design's choices, `enabled`, the parts the app fills, `interactionSource`, and the content last.

```kotlin
import org.novasoftwarefoundation.prism.*

// On Compose's clickable, with the button role and the theme's indication (Material's
// ripple under a MaterialTheme), inside the button's shape.
PrismButton(onClick = save, variant = PrismButtonVariant.Primary, loading = saving) {
    Text("Save")
}

// A small button, of any variant and tone; without `size`, it is Regular.
PrismButton(onClick = save, variant = PrismButtonVariant.Secondary, size = PrismButtonSize.Small) {
    Text("Save")
}

PrismButton(
    onClick = next,
    variant = PrismButtonVariant.Plain,
    padded = false,
    icon = { Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null) },
    iconSide = PrismSide.End,
) {
    Text("Next")
}

// Without progress it turns; with one, from 0 to 1, it shows it.
PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size20)
PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size32, progress = 0.4f)

// The box only; a row with a label toggles it with Modifier.toggleable and passes null.
PrismCheckbox(checked = remember, onCheckedChange = { remember = it })

// A BasicTextField on a TextFieldState; the field's label follows its control's focus.
PrismField(
    invalid = error != null,
    label = { Text("Email") },
    errorMessage = error?.let { message -> @Composable { Text(message) } },
) {
    PrismTextField(email, invalid = error != null, placeholder = { Text("name@example.org") })
}
PrismTextField(amount, prefix = { Text("€") })
PrismTextArea(notes, modifier = Modifier.height(128.dp))

PrismRadioGroup {
    PrismRadio(checked = choice == "yes", onClick = { choice = "yes" }) { Text("Yes") }
    PrismRadio(checked = choice == "no", onClick = { choice = "no" }) { Text("No") }
}

// On Material's ExposedDropdownMenuBox; the options are the app's, in Option.
PrismSelect(
    expanded = open,
    onExpandedChange = { open = it },
    icon = { Icon(Icons.Filled.ArrowDropDown, contentDescription = null) },
    label = { Text(country) },
) {
    for (name in countries) {
        Option(selected = name == country, onClick = { country = name; open = false }) {
            Text(name)
        }
    }
}

PrismTag(tone = PrismTagTone.Success) { Text("Done") }
PrismMessageBar(tone = PrismMessageBarTone.Warning) { Text("Your session ends in 5 minutes") }
PrismStepIndicator(status = PrismStepIndicatorStatus.Current) { Text("2") }
PrismImagePicker(
    shape = PrismImagePickerShape.Round,
    preview = { Image(photo, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) },
    button = { PrismButton(onClick = pick, variant = PrismButtonVariant.Secondary) { Text("Choose") } },
)
```

| Component | Compose |
| --- | --- |
| Button | `PrismButton(onClick) { … }`, on `Modifier.clickable` |
| Spinner | `PrismSpinner(progress = …)`, a `Canvas` with progress semantics |
| Checkbox | `PrismCheckbox(checked, onCheckedChange)`, on `Modifier.toggleable` |
| Text field, text area | `PrismTextField(state)`, `PrismTextArea(state)`, a `BasicTextField` with a decorator |
| Field | `PrismField(label =, errorMessage =) { control }` |
| Radio group, radio | `PrismRadioGroup { … }`, its radios in a row, its content `RowScope` (it was `ColumnScope` in 0.6.0) (`Modifier.selectableGroup`), `PrismRadio(checked, onClick) { label }` (`Modifier.selectable`) |
| Select | `PrismSelect(expanded, onExpandedChange, label =) { Option(…) { … } }`, on `ExposedDropdownMenuBox` |
| Image picker | `PrismImagePicker(preview =, button =)` |
| Tag, message bar, step indicator | `PrismTag(tone =)`, `PrismMessageBar(tone =)`, `PrismStepIndicator(status =)` |

- **Variants** are enum classes of the design's values (`PrismButtonVariant.Primary`, `PrismButtonTone.Danger`, `PrismSpinnerSize.Size16`), with the design's defaults: a button's tone is `Accent`, a spinner's size `Size24`, a tag's tone `Accent`, a message bar's `Info`, a step indicator's `Incomplete`. A button's variant and a spinner's color have none (`null`).
- **States Compose knows come from Compose:** pressed, hovered and focused from the `interactionSource`, a field's focus from its control's, a select's while its menu is open; disabled from `enabled`. The app gives the others: `loading`, `invalid`, a checkbox's and a radio's `checked`.
- **A text field with a prefix** takes it in `prefix`: a `Text`, or the app's own picker. The prefix fills the field's height before the text, and the field's border goes around both.
- **Material's `Text` and `Icon`** in a component take its text style and color, from `LocalTextStyle` and `LocalContentColor`.
- **A spinner** has progress semantics, so TalkBack reads its value; name it with `Modifier.semantics { contentDescription = "Uploading" }`.
- **An image picker's preview** shows the app's image cropped to it: `Modifier.fillMaxSize()` and `ContentScale.Crop`.
- **Each component's looks** are data too: `PrismButtonLooks(PrismButtonVariant.Primary, pressed = true).root` is the `PrismLook` the button draws, for a composable of the app's own. `Modifier.prismBox(look)`, `PrismText(look) { … }` and `PrismLookBox(look) { … }` draw a look on any content.

## Tokens

```kotlin
Prism.Colors.primary              // Color
Prism.Typography.title4           // PrismTypography: .textStyle, in sp
Prism.Typography.title4.emphasis  // PrismEmphasis.Headline; .weight is its family's weight for it
Prism.Spacing.px10                // Dp
Prism.Radii.default               // PrismRadius: .shape
Prism.Shadows.prismCard           // PrismShadow: .shadow for Modifier.dropShadow
```

Lengths are dp. Type is sp, so it follows the user's font size, to 200% on Android 14 and later; a box that holds text (a text field, a select, a message bar, a step indicator) grows with it, so the largest sizes cut nothing off. A line is as high as its typography's line height, as on the web, except where that is less than the font's own height, which Android never goes below. The fonts are the system font (Roboto), and for code (`mono`, `monosmall`, `monomedium`) the system's monospaced font (`FontFamily.Monospace`); the library bundles no fonts.

## License

MIT - See [LICENSE](https://github.com/novasoftwarefoundation/prism/blob/main/LICENSE) for details.
