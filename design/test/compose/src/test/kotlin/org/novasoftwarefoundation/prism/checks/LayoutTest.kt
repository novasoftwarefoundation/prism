package org.novasoftwarefoundation.prism.checks

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.input.rememberTextFieldState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.DeviceConfigurationOverride
import androidx.compose.ui.test.FontScale
import androidx.compose.ui.test.getBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.PrismButton
import org.novasoftwarefoundation.prism.PrismButtonVariant
import org.novasoftwarefoundation.prism.PrismMessageBar
import org.novasoftwarefoundation.prism.PrismRadio
import org.novasoftwarefoundation.prism.PrismRadioGroup
import org.novasoftwarefoundation.prism.PrismStepIndicator
import org.novasoftwarefoundation.prism.PrismTextField
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Where Prism's components put their text, at the default font size and at 200%, as iOS
 * and the web put it (Flux 10549420830, compared by hand on all three).
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LayoutTest(private val scale: Float) {
    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun scales(): List<Array<Any>> = listOf(arrayOf(1f), arrayOf(2f))

        private const val MESSAGE = "Your session ends in 5 minutes. Save your work to keep it."
    }

    @get:Rule
    val compose = createComposeRule()

    private val at get() = "at ${(scale * 100).toInt()}%"

    private fun show(content: @Composable () -> Unit) {
        compose.setContent {
            DeviceConfigurationOverride(DeviceConfigurationOverride.FontScale(scale)) {
                Box(Modifier.width(360.dp).testTag("box")) { content() }
            }
        }
    }

    private fun bounds(text: String): DpRect =
        compose.onNodeWithText(text, useUnmergedTree = true).getBoundsInRoot()

    private fun box(): DpRect = compose.onNodeWithTag("box").getBoundsInRoot()

    private fun layout(text: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        val node = compose.onNodeWithText(text, useUnmergedTree = true).fetchSemanticsNode()
        node.config[SemanticsActions.GetTextLayoutResult].action?.invoke(results)
        return results.single()
    }

    private fun middle(top: Dp, bottom: Dp): Float = (top.value + bottom.value) / 2

    // Its line in the middle of its box, as on iOS and the web; it was 5 dp above it.
    @Test
    fun aTextFieldCentresItsLine() {
        show { PrismTextField(rememberTextFieldState(), placeholder = { Text("Wage") }) }
        val (field, text) = box() to bounds("Wage")
        val off = middle(text.top, text.bottom) - middle(field.top, field.bottom)
        assertTrue("$at the text is ${-off} dp above the field's middle", abs(off) <= 1f)
    }

    // With a prefix too, where the prefix fills the height and its € was centred already.
    @Test
    fun aTextFieldWithAPrefixCentresItsLineAsItsPrefix() {
        show {
            PrismTextField(
                rememberTextFieldState(),
                placeholder = { Text("100") },
                prefix = { Text("€") },
            )
        }
        val (prefix, text) = bounds("€") to bounds("100")
        val off = middle(text.top, text.bottom) - middle(prefix.top, prefix.bottom)
        assertTrue("$at the amount is ${-off} dp above the €", abs(off) <= 1f)
    }

    // Centred across its width, each line, as on iOS and the web.
    @Test
    fun aMessageBarCentresItsMessage() {
        show { PrismMessageBar { Text("Saved") } }
        val (bar, text) = box() to bounds("Saved")
        val off = middle(text.left, text.right) - middle(bar.left, bar.right)
        assertTrue("$at the message is ${-off} dp left of the bar's middle", abs(off) <= 1f)
    }

    // Each line centred, the last and shorter one too, as on iOS and the web; centring the
    // block alone left-aligns its lines.
    @Test
    fun aMessageBarCentresEachLine() {
        show { PrismMessageBar { Text(MESSAGE) } }
        val (bar, text) = box() to bounds(MESSAGE)
        val layout = layout(MESSAGE)
        val last = layout.lineCount - 1
        assertTrue("$at the message is on ${layout.lineCount} line", last >= 1)
        val density = compose.density.density
        val line = text.left.value +
            (layout.getLineLeft(last) + layout.getLineRight(last)) / 2 / density
        val off = line - middle(bar.left, bar.right)
        assertTrue("$at its last line is ${-off} dp left of the bar's middle", abs(off) <= 1f)
    }

    // A message of more lines keeps 12 above and below them, where it had none at 200%.
    @Test
    fun aMessageBarKeepsRoomAroundItsLines() {
        show { PrismMessageBar { Text(MESSAGE) } }
        val (bar, text) = box() to bounds(MESSAGE)
        val above = text.top - bar.top
        val below = bar.bottom - text.bottom
        assertTrue("$at the message is $above below the bar's top", above >= 11.5.dp)
        assertTrue("$at the message is $below above the bar's bottom", below >= 11.5.dp)
    }

    // Side by side, as on iOS and the web; they stood one below the other.
    @Test
    fun aRadioGroupPutsItsRadiosInARow() {
        show {
            PrismRadioGroup {
                PrismRadio(checked = true, onClick = {}) { Text("Yes") }
                PrismRadio(checked = false, onClick = {}) { Text("No") }
            }
        }
        val (yes, no) = bounds("Yes") to bounds("No")
        assertTrue("$at No ($no) is not beside Yes ($yes)", no.left > yes.right)
        assertTrue("$at No ($no) is not level with Yes ($yes)", abs(no.top.value - yes.top.value) <= 1f)
    }

    // Room around the number where the circle grows with it, and still a circle, as on iOS;
    // at 200% the number filled it, and it grew taller than wide.
    @Test
    fun aStepIndicatorKeepsRoomAroundItsNumber() {
        show { PrismStepIndicator(Modifier.testTag("circle")) { Text("3") } }
        val circle = compose.onNodeWithTag("circle").getBoundsInRoot()
        val number = bounds("3")
        val (width, height) = (circle.right - circle.left) to (circle.bottom - circle.top)
        val room = height - (number.bottom - number.top)
        assertTrue("$at the circle is only $room taller than its number", room >= 7.5.dp)
        assertTrue("$at the circle is $width wide and $height high", abs(width.value - height.value) <= 1f)
    }

    // A size the app gives it is the box's, with its content in the middle of it: an icon
    // button at Android's 48 dp touch target, a step indicator made larger.
    @Test
    fun aSizeTheAppGivesIsTheBoxs() {
        show {
            Column {
                PrismButton(
                    onClick = {},
                    variant = PrismButtonVariant.Icon,
                    modifier = Modifier.testTag("button").size(48.dp),
                ) { Text("+") }
                PrismStepIndicator(Modifier.testTag("circle").size(32.dp)) { Text("3") }
            }
        }
        for ((tag, text, side) in listOf(Triple("button", "+", 48), Triple("circle", "3", 32))) {
            val (outer, inner) = compose.onNodeWithTag(tag).getBoundsInRoot() to bounds(text)
            val size = outer.right - outer.left
            assertTrue("$at the $tag is $size wide, not $side", abs(size.value - side) <= 0.5f)
            val across = middle(inner.left, inner.right) - middle(outer.left, outer.right)
            val down = middle(inner.top, inner.bottom) - middle(outer.top, outer.bottom)
            assertTrue("$at the $tag's text is $across dp across from its middle", abs(across) <= 1f)
            assertTrue("$at the $tag's text is $down dp down from its middle", abs(down) <= 1f)
        }
    }
}
