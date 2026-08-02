package com.matrixlauncher.theme

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.random.Random

/**
 * Fond animé façon "pluie de code" (Matrix digital rain).
 * Chaque colonne fait tomber des caractères aléatoires à sa propre vitesse,
 * avec un dégradé de luminosité (tête blanche -> vert -> fondu).
 */
class MatrixRainView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val glyphs = ("アイウエオカキクケコサシスセソタチツテトナニヌネノ" +
            "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ").toCharArray()

    private var columnCount = 0
    private var fontSize = 34f
    private lateinit var columnY: FloatArray
    private lateinit var columnSpeed: FloatArray
    private lateinit var columnLen: IntArray

    private val headPaint = Paint().apply {
        color = Color.parseColor("#E9FFEA")
        isAntiAlias = true
    }
    private val bodyPaint = Paint().apply {
        color = ContextColor
        isAntiAlias = true
    }

    private var animator: ValueAnimator? = null

    /** Contrôle globale de vitesse : 1f = normal, >1f = accéléré (utilisé pour l'effet de déverrouillage) */
    var speedMultiplier = 1f

    companion object {
        private val ContextColor = Color.parseColor("#00FF41")
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w <= 0 || h <= 0) return
        columnCount = (w / fontSize).toInt().coerceAtLeast(1)
        columnY = FloatArray(columnCount) { Random.nextFloat() * -h }
        columnSpeed = FloatArray(columnCount) { 4f + Random.nextFloat() * 10f }
        columnLen = IntArray(columnCount) { 8 + Random.nextInt(14) }
        headPaint.textSize = fontSize
        bodyPaint.textSize = fontSize
    }

    fun start() {
        if (animator?.isRunning == true) return
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 16
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { invalidate() }
            start()
        }
    }

    fun stop() {
        animator?.cancel()
        animator = null
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (columnCount == 0) return
        val h = height.toFloat()

        for (i in 0 until columnCount) {
            val x = i * fontSize
            var y = columnY[i]

            // dessine la traîne du bas (tête claire) vers le haut (fondu)
            for (j in 0 until columnLen[i]) {
                val charY = y - j * fontSize
                if (charY < -fontSize || charY > h + fontSize) continue
                val c = glyphs[Random.nextInt(glyphs.size)]
                val paint = if (j == 0) headPaint else bodyPaint
                val alpha = (255 * (1f - j.toFloat() / columnLen[i])).toInt().coerceIn(0, 255)
                paint.alpha = if (j == 0) 255 else alpha
                canvas.drawText(c.toString(), x, charY, paint)
            }

            columnY[i] += columnSpeed[i] * speedMultiplier
            if (columnY[i] - columnLen[i] * fontSize > h) {
                columnY[i] = Random.nextFloat() * -200f
                columnSpeed[i] = 4f + Random.nextFloat() * 10f
                columnLen[i] = 8 + Random.nextInt(14)
            }
        }
    }
}
