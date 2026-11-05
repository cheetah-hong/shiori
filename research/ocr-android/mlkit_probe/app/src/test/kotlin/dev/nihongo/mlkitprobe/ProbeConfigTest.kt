package dev.nihongo.mlkitprobe

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ProbeConfigTest {
    private fun config(vararg pairs: Pair<String, String>): ProbeConfig {
        val args = mapOf(*pairs)
        return ProbeConfig.from { args[it] }
    }

    @Test
    fun `no arguments run the upright bitmap pass`() {
        assertEquals(ProbeConfig(prepareOnly = false, inputDir = "upright", mode = InputMode.BITMAP, parallel = false), config())
    }

    @Test
    fun `prepare, mode, dir and parallel are read`() {
        val c = config("action" to "prepare", "mode" to "bitmap-exif", "dir" to "orig", "parallel" to "true")
        assertEquals(ProbeConfig(prepareOnly = true, inputDir = "orig", mode = InputMode.BITMAP_EXIF, parallel = true), c)
    }

    @Test
    fun `unknown action or mode is rejected`() {
        assertThrows(IllegalArgumentException::class.java) { config("action" to "delete") }
        assertThrows(IllegalArgumentException::class.java) { config("mode" to "camera") }
    }

    @Test
    fun `dir cannot leave the input folder`() {
        assertThrows(IllegalArgumentException::class.java) { config("dir" to "../files") }
        assertThrows(IllegalArgumentException::class.java) { config("dir" to "") }
    }

    @Test
    fun `non-finite numbers become json null`() {
        assertEquals(JSONObject.NULL, TextJson.num(Float.NaN))
        assertEquals(JSONObject.NULL, TextJson.num(Float.POSITIVE_INFINITY))
        assertEquals(0.5, TextJson.num(0.5f))
    }
}
