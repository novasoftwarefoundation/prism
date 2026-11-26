package org.novasoftwarefoundation.prism.checks

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.DeviceConfigurationOverride
import androidx.compose.ui.test.FontScale
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import java.io.File
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.*
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * The compare screen (design/test/compare/compare.sh): a component of every kind, as on iOS
 * (design/test/swiftui, CompareScreenTests) and the web (design/test/compare/web.mjs), at 100%
 * and at Android's largest font size, 200%, written to $PRISM_COMPARE as PNG. It makes
 * images and checks nothing: without PRISM_COMPARE it is skipped.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
// A 393 dp wide phone at 3 pixels a dp, as the iOS and web screens.
@Config(sdk = [34], qualifiers = "w393dp-h4000dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CompareScreenTest(private val scale: Int) {
    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}%")
        fun scales(): List<Array<Any>> = listOf(arrayOf(100), arrayOf(200))
    }

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun screen() {
        val out = System.getenv("PRISM_COMPARE").orEmpty()
        assumeTrue("PRISM_COMPARE names the folder for the images", out.isNotEmpty())
        // The spinner without progress stands still, so each run draws it the same.
        compose.mainClock.autoAdvance = false
        compose.setContent {
            DeviceConfigurationOverride(DeviceConfigurationOverride.FontScale(scale / 100f)) {
                Column(
                    Modifier.testTag("screen").width(393.dp).background(Color.White).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) { Screen() }
            }
        }
        compose.mainClock.advanceTimeByFrame()
        val image = compose.onNodeWithTag("screen").captureToImage().asAndroidBitmap()
        File(out).mkdirs()
        File(out, "compare-android-$scale.png").outputStream().use {
            image.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }

    @Composable
    private fun Screen() {
        Flow {
            for ((variant, name) in listOf(
                PrismButtonVariant.Primary to "Primary", PrismButtonVariant.Secondary to "Secondary",
                PrismButtonVariant.Soft to "Soft", PrismButtonVariant.Plain to "Plain",
                PrismButtonVariant.Link to "Link", PrismButtonVariant.Text to "Text",
            )) {
                PrismButton(onClick = {}, variant = variant) { Text(name) }
            }
            PrismButton(onClick = {}, variant = PrismButtonVariant.Icon) {
                Icon(Icons.Filled.Add, contentDescription = "Add")
            }
        }
        Flow {
            for ((tone, name) in listOf(
                PrismButtonTone.Success to "Success", PrismButtonTone.Warning to "Warning",
                PrismButtonTone.Danger to "Danger", PrismButtonTone.Neutral to "Neutral",
                PrismButtonTone.Highlight to "Highlight",
            )) {
                PrismButton(onClick = {}, variant = PrismButtonVariant.Primary, tone = tone) { Text(name) }
            }
            PrismButton(onClick = {}, variant = PrismButtonVariant.Primary, enabled = false) {
                Text("Disabled")
            }
            PrismButton(onClick = {}, variant = PrismButtonVariant.Primary, loading = true) {
                Text("Loading")
            }
        }
        PrismField(label = { Text("Email") }) {
            PrismTextField(rememberTextFieldState("someone@example.org"))
        }
        PrismField(
            invalid = true,
            label = { Text("Name") },
            errorMessage = { Text("Enter your name") },
        ) {
            PrismTextField(rememberTextFieldState(""), invalid = true)
        }
        PrismTextField(rememberTextFieldState("100"), prefix = { Text("€") })
        PrismTextArea(
            rememberTextFieldState("Notes about the visit, on more than one line."),
            modifier = Modifier.height(96.dp),
        )
        PrismSelect(
            false,
            onExpandedChange = {},
            icon = { Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null) },
            label = { Text("Bosnia and Herzegovina") },
        ) {}
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PrismCheckbox(checked = true, onCheckedChange = null)
            Text("Remember me")
        }
        PrismRadioGroup {
            PrismRadio(checked = true, onClick = {}) { Text("Yes") }
            PrismRadio(checked = false, onClick = {}) { Text("No") }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            PrismSpinner(variant = PrismSpinnerVariant.Accent)
            PrismSpinner(variant = PrismSpinnerVariant.Accent, size = PrismSpinnerSize.Size32, progress = 0.4f)
        }
        Flow {
            for ((tone, name) in listOf(
                PrismTagTone.Accent to "Accent", PrismTagTone.Success to "Success",
                PrismTagTone.Warning to "Warning", PrismTagTone.Danger to "Danger",
                PrismTagTone.Neutral to "Neutral",
            )) {
                PrismTag(tone = tone) { Text(name) }
            }
        }
        PrismMessageBar { Text("Saved") }
        PrismMessageBar(tone = PrismMessageBarTone.Warning) {
            Text("Your session ends in 5 minutes. Save your work to keep it.")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PrismStepIndicator(status = PrismStepIndicatorStatus.Complete) { Text("1") }
            PrismStepIndicator(status = PrismStepIndicatorStatus.Current) { Text("2") }
            PrismStepIndicator { Text("3") }
        }
        PrismImagePicker(
            preview = { Box(Modifier.fillMaxSize().background(Color(0xFFBBBBBB))) },
            button = {
                PrismButton(onClick = {}, variant = PrismButtonVariant.Primary) { Text("Choose a photo") }
            },
        )
    }

    @Composable
    private fun Flow(content: @Composable () -> Unit) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) { content() }
    }
}
