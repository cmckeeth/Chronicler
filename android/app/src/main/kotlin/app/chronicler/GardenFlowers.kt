package app.chronicler

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

// Flower hues (light -> saturated), ported 1:1 from the web app's FLOWER_HUES.
enum class FlowerHue(val light: Color, val dark: Color) {
    ROSE(Color(0xFFFFD6E6), Color(0xFFFF4F8E)),
    GOLD(Color(0xFFFFF0BF), Color(0xFFFFA61F)),
    LILAC(Color(0xFFECD6FF), Color(0xFF9B54FF)),
    WHITE(Color(0xFFFFFFFF), Color(0xFFCFE0E6)),
    CORAL(Color(0xFFFFD9BF), Color(0xFFFF6A3C)),
}

// Golden center radial gradient (#FFE784 -> #F0A800 -> #9C6400), ported from the web.
private val CENTER_LIGHT = Color(0xFFFFE784)
private val CENTER_MID = Color(0xFFF0A800)
private val CENTER_DARK = Color(0xFF9C6400)

// Draw one hand-built vector bloom centred in this DrawScope: a golden center circle
// surrounded by two offset rings of gradient-shaded elliptical petals. Mirrors the web
// SVG <Flower>: petals are elongated ellipses (rx = 0.38 * ry) laid out in a ring.
fun DrawScope.drawFlower(hue: FlowerHue, petals: Int = 13) {
    val w = size.width
    val cx = w * 0.5f
    val cy = w * 0.5f
    val unit = w / 100f          // the web art is authored on a 100x100 viewBox

    // petalBrush: light center -> saturated edge (cx 50%, cy 84%) per the web gradient.
    fun ring(count: Int, ry: Float, ovalCy: Float, rotOffsetDeg: Float) {
        val rx = ry * 0.38f
        for (k in 0 until count) {
            val angDeg = rotOffsetDeg + (360f / count) * k
            rotateRad(Math.toRadians(angDeg.toDouble()).toFloat(), pivot = Offset(cx, cy)) {
                val ovalW = rx * 2 * unit
                val ovalH = ry * 2 * unit
                val topLeft = Offset(cx - ovalW / 2f, ovalCy * unit - ovalH / 2f)
                drawOval(
                    brush = Brush.radialGradient(
                        colorStops = arrayOf(
                            0f to hue.light,
                            0.62f to hue.dark,
                            1f to hue.dark.copy(alpha = 0.85f),
                        ),
                        center = Offset(topLeft.x + ovalW * 0.5f, topLeft.y + ovalH * 0.84f),
                        radius = ovalH * 0.78f,
                    ),
                    topLeft = topLeft,
                    size = Size(ovalW, ovalH),
                    alpha = 0.95f,
                )
            }
        }
    }

    ring(petals, ry = 26f, ovalCy = 26f, rotOffsetDeg = 0f)
    ring(petals, ry = 19f, ovalCy = 33f, rotOffsetDeg = 360f / petals / 2f)

    // Golden textured center.
    val centerR = 13f * unit
    drawCircle(
        brush = Brush.radialGradient(
            colorStops = arrayOf(0f to CENTER_LIGHT, 0.55f to CENTER_MID, 1f to CENTER_DARK),
            center = Offset(cx, cy - centerR * 0.16f),
            radius = centerR * 1.2f,
        ),
        radius = centerR,
        center = Offset(cx, cy),
    )
    // Speckle dots, like the web's seed cluster.
    for (k in 0 until 10) {
        drawCircle(
            color = Color(0xFF7A4E00).copy(alpha = 0.5f),
            radius = 1.5f * unit,
            center = Offset(cx + 7f * unit * cos(k * 2.4f), cy + 7f * unit * sin(k * 2.4f)),
        )
    }
}

// A single swaying flower placed at an alignment + offset. Non-interactive.
@Composable
private fun BoxScope.SwayFlower(
    hue: FlowerHue,
    sizeDp: Int,
    align: Alignment,
    xDp: Int,
    yDp: Int,
    swayMs: Int,
    reverse: Boolean,
    petals: Int = 13,
) {
    val t = rememberInfiniteTransition(label = "swayFlower")
    val deg by t.animateFloat(
        initialValue = if (reverse) 6f else -6f,
        targetValue = if (reverse) -6f else 6f,
        animationSpec = infiniteRepeatable(tween(swayMs, easing = LinearEasing), RepeatMode.Reverse),
        label = "sway",
    )
    Canvas(
        Modifier
            .align(align)
            .offset(x = xDp.dp, y = yDp.dp)
            .size(sizeDp.dp)
            .rotate(deg),
    ) { drawFlower(hue, petals) }
}

// GARDEN-only soft BACKGROUND wallpaper: several large vector flowers at ~50% opacity,
// gently swaying, behind the foreground content. Non-interactive. Mirrors the web GardenFX
// bg-flower layer (varied hue/size/position).
@Composable
fun GardenFlowerBackdrop(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().alpha(0.5f)) {
        SwayFlower(FlowerHue.ROSE, sizeDp = 320, align = Alignment.TopStart, xDp = -90, yDp = -60, swayMs = 9000, reverse = false)
        SwayFlower(FlowerHue.GOLD, sizeDp = 230, align = Alignment.TopEnd, xDp = 60, yDp = 150, swayMs = 11000, reverse = true, petals = 15)
        SwayFlower(FlowerHue.LILAC, sizeDp = 260, align = Alignment.BottomStart, xDp = 90, yDp = 60, swayMs = 13000, reverse = false)
        SwayFlower(FlowerHue.CORAL, sizeDp = 185, align = Alignment.CenterStart, xDp = -45, yDp = 40, swayMs = 10000, reverse = true)
        SwayFlower(FlowerHue.WHITE, sizeDp = 200, align = Alignment.Center, xDp = 30, yDp = -80, swayMs = 12000, reverse = false, petals = 14)
    }
}
