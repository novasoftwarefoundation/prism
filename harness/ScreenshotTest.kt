package org.novasoftwarefoundation.prism.checks

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.*
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// The components Joeri compared (Flux 10549420830), one screen at 100% and at 200% font size,
// written to $PRISM_SHOTS as PNG. Screenshots only: not part of the PR's checks.
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w393dp-h1400dp-xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenshotTest(private val scale: Float) {
    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun scales(): List<Array<Any>> = listOf(arrayOf(1f), arrayOf(2f))
    }

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun screen() {
        val out = File(System.getenv("PRISM_SHOTS") ?: return)
        compose.setContent {
            DeviceConfigurationOverride(DeviceConfigurationOverride.FontScale(scale)) {
                Column(
                    Modifier.testTag("screen").width(393.dp).background(Color.White).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    PrismTextField(rememberTextFieldState("someone@example.org"))
                    PrismTextField(rememberTextFieldState("100"), prefix = { Text("€") })
                    PrismSelect(
                        false,
                        onExpandedChange = {},
                        icon = { Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null) },
                        label = { Text("Bosnia and Herzegovina") },
                    ) {}
                    PrismRadioGroup {
                        PrismRadio(checked = true, onClick = {}) { Text("Yes") }
                        PrismRadio(checked = false, onClick = {}) { Text("No") }
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
                            PrismButton(onClick = {}, variant = PrismButtonVariant.Primary) {
                                Text("Choose a photo")
                            }
                        },
                    )
                }
            }
        }
        val image = compose.onNodeWithTag("screen").captureToImage().asAndroidBitmap()
        out.mkdirs()
        File(out, "android-${(scale * 100).toInt()}.png").outputStream().use {
            image.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}
