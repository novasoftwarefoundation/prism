package org.novasoftwarefoundation.prism.checks

import com.google.gson.Gson
import com.google.gson.JsonParser
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
 * an Int, Gson's and Moshi's maps the Double `500.0`, Gson's tree a `LazilyParsedNumber`. A whole
 * number is the number; a fraction, a string, a boolean or a number out of range fails, never
 * clamped or coerced.
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
    fun whatGsonGivesIsTheNumber() {
        val json = """{"debounce_ms": 500}"""

        // Its tree: a JsonPrimitive whose number is a LazilyParsedNumber.
        val number = JsonParser.parseString(json).asJsonObject["debounce_ms"].asNumber
        assertEquals("com.google.gson.internal.LazilyParsedNumber", number.javaClass.name)
        assertEquals(500, read(number))

        // Its map: a Double.
        @Suppress("UNCHECKED_CAST")
        val map = Gson().fromJson(json, Map::class.java) as Map<String, Any?>
        assertEquals(500, PrismTextFieldInputMetadata.from(map).debounceMs)

        val fraction = JsonParser.parseString("""{"debounce_ms": 500.5}""").asJsonObject
        assertThrows(IllegalArgumentException::class.java) { read(fraction["debounce_ms"].asNumber) }
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
