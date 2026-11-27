package org.novasoftwarefoundation.prism.checks

import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.sp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.novasoftwarefoundation.prism.Prism
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * The code typography: `mono`, `monosmall` and `monomedium` are Android's monospaced system
 * font (`FontFamily.Monospace`) at the reading weight and their sizes, as SF Mono is on iOS
 * and macOS (design/test/swiftui). No other typography is monospaced.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
// Android's own text layout, so text has its real width.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MonoTest {
    @get:Rule
    val compose = createComposeRule()

    private val mono = mapOf(
        "mono" to Triple(Prism.Typography.mono, 20, 24),
        "monosmall" to Triple(Prism.Typography.monosmall, 16, 24),
        "monomedium" to Triple(Prism.Typography.monomedium, 20, 30),
    )

    @Test
    fun theMonoTypographiesAreTheMonospacedSystemFontAtTheirSizes() {
        for ((name, expected) in mono) {
            val (typography, size, lineHeight) = expected
            assertEquals(name, FontFamily.Monospace, typography.textStyle.fontFamily)
            assertEquals(name, 300, typography.weight)
            assertEquals(name, size.sp, typography.size)
            assertEquals(name, lineHeight.sp, typography.lineHeight)
        }
        assertEquals(FontFamily.Default, Prism.Typography.bodysmall.textStyle.fontFamily)
        assertEquals(FontFamily.Default, Prism.Typography.bodymedium.textStyle.fontFamily)
    }

    // A narrow and a wide letter are as wide in a monospaced font, not in the body text's.
    @Test
    fun theMonoTypographiesDrawEveryLetterAsWide() {
        lateinit var measurer: TextMeasurer
        compose.setContent { measurer = rememberTextMeasurer() }
        compose.waitForIdle()

        fun width(text: String, style: TextStyle) = measurer.measure(text, style).size.width

        for ((name, expected) in mono) {
            val style = expected.first.textStyle
            assertEquals(name, width("iiiiiiii", style), width("MMMMMMMM", style))
        }
        val body = Prism.Typography.bodysmall.textStyle
        assertNotEquals(width("iiiiiiii", body), width("MMMMMMMM", body))
    }
}
