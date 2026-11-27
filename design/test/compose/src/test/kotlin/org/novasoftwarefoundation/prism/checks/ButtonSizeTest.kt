package org.novasoftwarefoundation.prism.checks

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.novasoftwarefoundation.prism.Prism
import org.novasoftwarefoundation.prism.PrismButtonLooks
import org.novasoftwarefoundation.prism.PrismButtonSize
import org.novasoftwarefoundation.prism.PrismButtonVariant
import org.novasoftwarefoundation.prism.PrismInsets

/**
 * A button's sizes (ADR 0006): regular, the default, is the look a button has always had;
 * small has the buttonsmall typography, less padding and a 16dp icon.
 */
class ButtonSizeTest {
    private val small = PrismInsets(8.dp, 12.dp, 8.dp, 12.dp)

    @Test
    fun regularIsTheDefaultLook() {
        val root = PrismButtonLooks(PrismButtonVariant.Primary).root
        assertEquals(root, PrismButtonLooks(PrismButtonVariant.Primary, size = PrismButtonSize.Regular).root)
        assertEquals(Prism.Typography.button, root.typography)
        assertEquals(PrismInsets(15.dp, 16.dp, 15.dp, 16.dp), root.padding)
        assertNull(PrismButtonLooks(PrismButtonVariant.Primary, withIcon = true).icon.size)
    }

    @Test
    fun smallHasItsTypographyPaddingAndIcon() {
        for (variant in listOf(PrismButtonVariant.Primary, PrismButtonVariant.Soft, PrismButtonVariant.Plain, PrismButtonVariant.Text)) {
            val root = PrismButtonLooks(variant, size = PrismButtonSize.Small).root
            assertEquals(Prism.Typography.buttonsmall, root.typography)
            assertEquals("$variant", small, root.padding)
            assertEquals(
                "$variant pressed",
                PrismInsets(9.dp, 12.dp, 7.dp, 12.dp),
                PrismButtonLooks(variant, size = PrismButtonSize.Small, pressed = true).root.padding,
            )
        }
        assertEquals(
            PrismInsets(6.dp, 12.dp, 6.dp, 12.dp),
            PrismButtonLooks(PrismButtonVariant.Secondary, size = PrismButtonSize.Small).root.padding,
        )
        assertEquals(
            small,
            PrismButtonLooks(PrismButtonVariant.Primary, size = PrismButtonSize.Small, withIcon = true).root.padding,
        )
        assertEquals(
            16.dp,
            PrismButtonLooks(PrismButtonVariant.Primary, size = PrismButtonSize.Small, withIcon = true).icon.size,
        )
        assertEquals(16.dp, PrismButtonLooks(PrismButtonVariant.Icon, size = PrismButtonSize.Small).root.size)
    }
}
