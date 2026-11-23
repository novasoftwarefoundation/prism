package org.novasoftwarefoundation.prism.checks

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.input.TextFieldState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import org.novasoftwarefoundation.prism.*

// The examples of README.md and targets/kotlin/README.md, as code that must compile with
// the library: a change to its API fails here until the READMEs follow.

@Composable
internal fun RootReadme(save: () -> Unit, saving: Boolean, error: String?, email: TextFieldState) {
    PrismButton(
        onClick = save,
        variant = PrismButtonVariant.Primary,
        tone = PrismButtonTone.Danger,
        loading = saving,
    ) {
        Text("Save")
    }

    // email is a TextFieldState; the field's label follows its text field's focus.
    PrismField(
        invalid = error != null,
        label = { Text("Email") },
        errorMessage = error?.let { message -> @Composable { Text(message) } },
    ) {
        PrismTextField(email, invalid = error != null)
    }

    PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size32, progress = 0.4f)
    PrismTag(tone = PrismTagTone.Success) { Text("Done") }
}

@Composable
internal fun LibraryReadme(
    save: () -> Unit,
    next: () -> Unit,
    pick: () -> Unit,
    saving: Boolean,
    error: String?,
    email: TextFieldState,
    amount: TextFieldState,
    notes: TextFieldState,
    countries: List<String>,
    photo: ImageBitmap,
) {
    var remember by remember { mutableStateOf(false) }
    var choice by remember { mutableStateOf("yes") }
    var open by remember { mutableStateOf(false) }
    var country by remember { mutableStateOf(countries.first()) }

    PrismButton(onClick = save, variant = PrismButtonVariant.Primary, loading = saving) {
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

    PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size20)
    PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size32, progress = 0.4f)

    PrismCheckbox(checked = remember, onCheckedChange = { remember = it })

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

    val looks = PrismButtonLooks(PrismButtonVariant.Primary, pressed = true).root
    PrismLookBox(looks) { Text("Mine") }
    check(Prism.Typography.title4.emphasis == PrismEmphasis.Headline)
    check(Prism.Typography.title4.weight == 800)
}
