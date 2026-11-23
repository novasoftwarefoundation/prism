package org.novasoftwarefoundation.prism.checks

import androidx.compose.foundation.IndicationNodeFactory
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.PrismButton
import org.novasoftwarefoundation.prism.PrismButtonVariant
import org.novasoftwarefoundation.prism.PrismCheckbox
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * A control's indication (Material's ripple under a MaterialTheme) is drawn inside its rounded
 * shape, as Material clips its own controls' ripple, not over the box's square corners. The
 * indication here paints the whole area it is given, so its corner pixel shows whether it was
 * clipped.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class IndicationTest {
    @get:Rule
    val compose = createComposeRule()

    private object Paint : IndicationNodeFactory {
        override fun create(interactionSource: InteractionSource): DelegatableNode =
            object : Modifier.Node(), DrawModifierNode {
                override fun ContentDrawScope.draw() {
                    drawContent()
                    drawRect(Color.Red)
                }
            }

        override fun equals(other: Any?): Boolean = other === this

        override fun hashCode(): Int = 0
    }

    private fun corners(content: @Composable () -> Unit): Pair<Color, Color> {
        compose.setContent { CompositionLocalProvider(LocalIndication provides Paint, content = content) }
        val pixels = compose.onNodeWithTag("control").captureToImage().toPixelMap()
        return pixels[0, 0] to pixels[pixels.width / 2, pixels.height / 2]
    }

    @Test
    fun aButtonsIndicationIsInsideItsShape() {
        val (corner, middle) = corners {
            PrismButton(onClick = {}, Modifier.testTag("control"), PrismButtonVariant.Primary) {
                Text("Save")
            }
        }
        assertEquals(Color.Red, middle)
        assertNotEquals("the indication covers the button's rounded corner", Color.Red, corner)
    }

    @Test
    fun aCheckboxsIndicationIsInsideItsShape() {
        val (corner, middle) = corners {
            PrismCheckbox(checked = false, onCheckedChange = {}, Modifier.testTag("control"))
        }
        assertEquals(Color.Red, middle)
        assertNotEquals("the indication covers the checkbox's rounded corner", Color.Red, corner)
    }
}
