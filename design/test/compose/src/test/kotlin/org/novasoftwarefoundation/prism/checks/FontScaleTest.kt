package org.novasoftwarefoundation.prism.checks

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.test.DeviceConfigurationOverride
import androidx.compose.ui.test.FontScale
import androidx.compose.ui.test.getBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.PrismButton
import org.novasoftwarefoundation.prism.PrismButtonVariant
import org.novasoftwarefoundation.prism.PrismField
import org.novasoftwarefoundation.prism.PrismMessageBar
import org.novasoftwarefoundation.prism.PrismRadio
import org.novasoftwarefoundation.prism.PrismSelect
import org.novasoftwarefoundation.prism.PrismStepIndicator
import org.novasoftwarefoundation.prism.PrismStepIndicatorStatus
import org.novasoftwarefoundation.prism.PrismTag
import org.novasoftwarefoundation.prism.PrismTextArea
import org.novasoftwarefoundation.prism.PrismTextField
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Every Prism component that holds text, at the default font size and at Android's largest,
 * 200%: its text grows, and stays inside its box, which grows with it where it must, as with
 * Dynamic Type on iOS (design/test/swiftui). On the web a fixed height lets the text overflow;
 * on Android it would be drawn outside its box, over what is around it.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [34])
// Android's own text layout, so text has its real size.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FontScaleTest(private val name: String) {
    companion object {
        private val components: Map<String, @Composable () -> Unit> = mapOf(
            "button" to {
                PrismButton(onClick = {}, variant = PrismButtonVariant.Primary) { Text(TEXT) }
            },
            "text button" to {
                PrismButton(onClick = {}, variant = PrismButtonVariant.Text) { Text(TEXT) }
            },
            "text field" to { PrismTextField(rememberTextFieldState(TEXT)) },
            "text area" to { PrismTextArea(rememberTextFieldState(TEXT)) },
            "field" to {
                PrismField(label = { Text(TEXT) }, errorMessage = { Text("Required") }) {}
            },
            "radio" to { PrismRadio(checked = true, onClick = {}) { Text(TEXT) } },
            "select" to { PrismSelect(false, onExpandedChange = {}, label = { Text(TEXT) }) {} },
            "tag" to { PrismTag { Text(TEXT) } },
            "message bar" to { PrismMessageBar { Text(TEXT) } },
            // Wider than its circle at 200%: the circle must grow, not cut it off.
            "step indicator" to {
                PrismStepIndicator(status = PrismStepIndicatorStatus.Current) { Text(STEP) }
            },
        )

        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun names(): List<Array<Any>> = components.keys.map { arrayOf(it) }

        private const val TEXT = "Wage"
        private const val STEP = "12"
    }

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun keepsItsGrowingTextInside() {
        val component = components.getValue(name)
        val text = if (name == "step indicator") STEP else TEXT
        compose.setContent {
            Column(Modifier.width(360.dp)) {
                for (scale in listOf(1f, 2f)) {
                    DeviceConfigurationOverride(DeviceConfigurationOverride.FontScale(scale)) {
                        Box(Modifier.testTag("at $scale")) { component() }
                    }
                }
            }
        }

        val boxes = listOf(1f, 2f).map { compose.onNodeWithTag("at $it").getBoundsInRoot() }
        val texts = compose.onAllNodesWithText(text, useUnmergedTree = true)
        for ((index, box) in boxes.withIndex()) {
            val at = "$name at ${index + 1}00%"
            val inside = texts[index].getBoundsInRoot()
            assertTrue("$at: its text $inside is outside $box", box.holds(inside))
            // A box too small for its text constrains it: the text then wraps, or is taller
            // than the box lets it be, inside bounds that still fit.
            val layout = layout(texts[index])
            assertTrue("$at: its text wraps onto ${layout.lineCount} lines", layout.lineCount == 1)
            assertTrue("$at: its text is taller than its box lets it be", !layout.didOverflowHeight)
        }
        // The text did grow: the box held the larger text, not the same one.
        val (small, large) = (0..1).map { texts[it].getBoundsInRoot().let { r -> r.bottom - r.top } }
        assertTrue("$name: its text at 200% ($large) is not larger than at 100% ($small)", large > small)
    }

    private fun layout(text: SemanticsNodeInteraction): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        val getLayout = text.fetchSemanticsNode().config[SemanticsActions.GetTextLayoutResult]
        getLayout.action?.invoke(results)
        return results.single()
    }

    // Whether `other` is inside this box, to half a dp.
    private fun DpRect.holds(other: DpRect): Boolean {
        val box = Rect(left.value, top.value, right.value, bottom.value).inflate(0.5f)
        return box.left <= other.left.value && box.top <= other.top.value &&
            box.right >= other.right.value && box.bottom >= other.bottom.value
    }

}
