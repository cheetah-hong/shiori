package com.nihongoapp.shiori

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Which files the audio channel may play: only real files inside the cache folder. */
class AudioPathTest {
    private val base: File = Files.createTempDirectory("audio_path").toFile()
    private val cache = File(base, "cache").apply { mkdirs() }

    private fun file(dir: File, name: String) = File(dir, name).apply {
        parentFile?.mkdirs()
        writeText("RIFF")
    }

    @Test
    fun aFileInsideTheCacheFolderIsPlayed() {
        val sound = file(cache, "speech/abc.wav")
        assertEquals(sound.canonicalFile, AudioPath.cachedFile(sound.path, cache))
    }

    @Test
    fun pathsOutsideTheCacheFolderAreRefused() {
        val outside = file(base, "other.wav")
        val sibling = file(File(base, "cache2"), "x.wav")
        assertNull(AudioPath.cachedFile(outside.path, cache))
        assertNull(AudioPath.cachedFile(sibling.path, cache))
        assertNull(AudioPath.cachedFile("${cache.path}/../other.wav", cache))
        assertNull(AudioPath.cachedFile("speech/abc.wav", cache))
    }

    @Test
    fun theFolderItselfAndMissingFilesAreRefused() {
        assertNull(AudioPath.cachedFile(cache.path, cache))
        assertNull(AudioPath.cachedFile(File(cache, "none.wav").path, cache))
    }

    @Test
    fun aLinkOutOfTheCacheFolderIsRefused() {
        val outside = file(base, "secret.wav")
        val link = File(cache, "link.wav")
        Files.createSymbolicLink(link.toPath(), outside.toPath())
        assertNull(AudioPath.cachedFile(link.path, cache))
    }
}
