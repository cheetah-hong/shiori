package com.nihongoapp.shiori

import kotlin.math.abs

/**
 * Pure geometry of the ML Kit channel, kept free of Android types so it runs in JVM unit tests.
 *
 * ML Kit joins table columns into one line (headword, a printed ★ and reading come back together). The
 * channel returns "pieces" instead: a line cut where two elements are far apart and around a noise
 * symbol (★ and its misreads, which the Dart side drops), with x taken
 * from the glyph boxes. It also turns the boxes of a photo whose text lies sideways.
 */
object OcrGeometry {
    /** Element gap, in line heights, that separates two columns (words in a cell are <= 0.98 apart). */
    const val COLUMN_GAP = 1.1

    /**
     * Symbols that are noise in a cell (the textbook's ★ and how ML Kit misreads it). Each becomes a
     * piece of its own so the Dart clean-up can drop it without cutting into a word.
     */
    const val NOISE_SYMBOLS = "★*☆＊"
    private val noiseTexts = NOISE_SYMBOLS.map { it.toString() }.toSet()

    /** A line angle further than this from a quarter turn says nothing about the page direction. */
    private const val ANGLE_TOLERANCE = 20.0

    /** Lines shorter than this have unreliable angles. */
    private const val MIN_ANGLE_CHARS = 3

    /** Axis-aligned box in pixels of the frame the boxes live in. */
    data class Box(val left: Double, val top: Double, val right: Double, val bottom: Double) {
        val height get() = bottom - top

        /** One clockwise quarter turn inside a frame [frameHeight] pixels high. */
        fun turnedClockwise(frameHeight: Double) = Box(frameHeight - bottom, left, frameHeight - top, right)

        companion object {
            fun union(boxes: List<Box>) = Box(
                boxes.minOf { it.left },
                boxes.minOf { it.top },
                boxes.maxOf { it.right },
                boxes.maxOf { it.bottom },
            )
        }
    }

    data class Symbol(val text: String, val box: Box?, val confidence: Double?)

    data class Element(val text: String, val box: Box?, val confidence: Double?, val symbols: List<Symbol>)

    data class Line(
        val text: String,
        val box: Box?,
        val confidence: Double?,
        val angle: Double?,
        val elements: List<Element>,
    )

    /** One returned line: [box] in frame pixels. */
    data class Piece(val text: String, val confidence: Double?, val box: Box)

    /**
     * Clockwise quarter turns that make the text upright: the median line angle plus the rotation
     * handed to ML Kit with the image (ML Kit reports angles in the bitmap's own frame, boxes in the
     * turned one). 0 when upright or unclear.
     */
    fun textTurns(lines: List<Line>, inputRotation: Int): Int {
        val angles = lines.filter { it.text.trim().length >= MIN_ANGLE_CHARS }.mapNotNull { it.angle }
            .filter { it.isFinite() }
        if (angles.isEmpty()) return 0
        val a = ((median(angles) + inputRotation + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
        val snapped = listOf(0.0, 90.0, -90.0, 180.0, -180.0).minBy { abs(a - it) }
        if (abs(a - snapped) > ANGLE_TOLERANCE) return 0
        return when (snapped) {
            -90.0 -> 1
            180.0, -180.0 -> 2
            90.0 -> 3
            else -> 0
        }
    }

    /** [lines] with every box turned [turns] quarter turns clockwise, and the new frame size. */
    fun turned(lines: List<Line>, turns: Int, width: Double, height: Double): Triple<List<Line>, Double, Double> {
        var out = lines
        var w = width
        var h = height
        repeat(((turns % 4) + 4) % 4) {
            val frameHeight = h
            fun Box?.turn() = this?.turnedClockwise(frameHeight)
            out = out.map { l ->
                l.copy(
                    box = l.box.turn(),
                    elements = l.elements.map { e ->
                        e.copy(box = e.box.turn(), symbols = e.symbols.map { s -> s.copy(box = s.box.turn()) })
                    },
                )
            }
            w = h.also { h = w }
        }
        return Triple(out, w, h)
    }

    private data class Run(val text: String, val box: Box, val noise: Boolean, val confidences: List<Double?>)

    /** An element as runs of symbols; a noise symbol is a run of its own. Pieces without a box are dropped. */
    private fun runs(e: Element): List<Run> {
        val boxed = e.symbols.mapNotNull { s -> s.box?.let { s to it } }
        if (boxed.isEmpty()) {
            return if (e.box == null) emptyList() else listOf(Run(e.text, e.box, false, listOf(e.confidence)))
        }
        val out = mutableListOf<MutableRun>()
        for ((s, box) in boxed) {
            val noise = s.text in noiseTexts
            val last = out.lastOrNull()
            if (last != null && !noise && !last.noise) {
                last.add(s.text, box, s.confidence)
            } else {
                out.add(MutableRun(s.text, box, noise, s.confidence))
            }
        }
        return out.map { it.toRun() }
    }

    /**
     * Glyphs of [line] that a cut line loses: those without a box, in elements that have other boxed
     * glyphs, or in elements without any box. A line that needs no cut keeps its whole text.
     */
    fun glyphsWithoutBox(line: Line): Int {
        if (line.box == null || segments(line).size <= 1) return 0
        return line.elements.sumOf { e ->
            when {
                e.symbols.any { it.box != null } -> e.symbols.count { it.box == null }
                e.box == null -> e.text.length
                else -> 0
            }
        }
    }

    private class MutableRun(text: String, box: Box, val noise: Boolean, confidence: Double?) {
        private val text = StringBuilder(text)
        private val boxes = mutableListOf(box)
        private val confidences = mutableListOf(confidence)

        fun add(t: String, b: Box, c: Double?) {
            text.append(t)
            boxes.add(b)
            confidences.add(c)
        }

        fun toRun() = Run(text.toString(), Box.union(boxes), noise, confidences.toList())
    }

    /**
     * [line] cut at element gaps wider than [COLUMN_GAP] line heights and around noise symbols.
     * Pieces take x from their glyph boxes and y from the line box (the parser's height rules were
     * set on line boxes); confidence is the mean glyph confidence. A line that needs no cut comes back
     * as it is.
     */
    fun segments(line: Line): List<Piece> {
        val lineBox = line.box ?: return emptyList()
        val lineHeight = lineBox.height
        val segs = mutableListOf<Segment>()
        var prevRight: Double? = null
        for (e in line.elements) {
            for ((k, r) in runs(e).withIndex()) {
                val wideGap = k == 0 && prevRight != null && r.box.left - prevRight > COLUMN_GAP * lineHeight
                val last = segs.lastOrNull()
                if (last == null || r.noise || last.noise || wideGap) {
                    segs.add(Segment(StringBuilder(r.text), mutableListOf(r.box), r.confidences.toMutableList(), r.noise))
                } else {
                    last.text.append(if (k == 0) " " else "").append(r.text)
                    last.boxes.add(r.box)
                    last.confidences.addAll(r.confidences)
                }
                prevRight = r.box.right
            }
        }
        if (segs.size <= 1) return listOf(Piece(line.text, line.confidence, lineBox))
        return segs.map { s ->
            val cs = s.confidences.filterNotNull()
            val x = Box.union(s.boxes)
            Piece(
                s.text.toString(),
                if (cs.isEmpty()) line.confidence else cs.average(),
                Box(x.left, lineBox.top, x.right, lineBox.bottom),
            )
        }
    }

    private class Segment(
        val text: StringBuilder,
        val boxes: MutableList<Box>,
        val confidences: MutableList<Double?>,
        val noise: Boolean,
    )

    private fun median(values: List<Double>): Double {
        val s = values.sorted()
        val mid = s.size / 2
        return if (s.size % 2 == 1) s[mid] else (s[mid - 1] + s[mid]) / 2
    }
}
