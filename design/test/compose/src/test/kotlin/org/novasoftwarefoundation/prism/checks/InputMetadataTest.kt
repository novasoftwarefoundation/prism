package org.novasoftwarefoundation.prism.checks

import java.math.BigDecimal
import java.math.BigInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import org.novasoftwarefoundation.prism.PrismTextAreaInputMetadata
import org.novasoftwarefoundation.prism.PrismTextFieldInputMetadata

/**
 * The input metadata read from values a JSON parser gives (ADR 0012): org.json gives `500` as
 * an Int, Gson and Moshi as the Double `500.0`. A whole number is the number; a fraction, a
 * string, a boolean or a number out of range fails, never clamped or coerced.
 */
class InputMetadataTest {
    private fun read(value: Any?) =
        PrismTextFieldInputMetadata.from(mapOf("debounce_ms" to value)).debounceMs

    @Test
    fun aWholeNumberOfAnyKindIsTheNumber() {
        assertEquals(500, read(500))
        assertEquals(500, read(500L))
        assertEquals(500, read(500.0))
        assertEquals(500, read(500f))
        assertEquals(500, read(BigDecimal("500.0")))
        assertEquals(500, read(BigInteger.valueOf(500)))
        assertEquals(Int.MAX_VALUE, read(2147483647.0))
        assertEquals(250, PrismTextAreaInputMetadata.from(mapOf("debounce_ms" to 250.0)).debounceMs)
    }

    @Test
    fun noValueIsNoDebounce() {
        assertNull(read(null))
        assertNull(PrismTextFieldInputMetadata.from(emptyMap()).debounceMs)
    }

    @Test
    fun anythingElseFails() {
        for (value in listOf(500.5, Double.NaN, Double.POSITIVE_INFINITY, 3e9, 3_000_000_000L,
            BigDecimal("500.5"), "500", true, 0, 0.0, -1.0)) {
            assertThrows("$value", IllegalArgumentException::class.java) { read(value) }
        }
        assertThrows(IllegalArgumentException::class.java) {
            PrismTextFieldInputMetadata.from(mapOf("debounce" to 500))
        }
    }
}
