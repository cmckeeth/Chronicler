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
import androidx.compose.foundation.layout.BoxWithConstraints
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

// Rose hues (light -> mid -> deep). All garden flowers are roses now; mirrors the web's
// ROSE-family FLOWER_HUES. Outer/mid petals use light->mid; inner/center use mid->deep.
enum class FlowerHue(val light: Color, val mid: Color, val deep: Color) {
    ROSE(Color(0xFFFFD9E8), Color(0xFFF0497F), Color(0xFFA81450)),
    RED(Color(0xFFFF9FB2), Color(0xFFE21F3C), Color(0xFF860F24)),
    BLUSH(Color(0xFFFFE6EE), Color(0xFFFF8FB0), Color(0xFFD2658A)),
    CRIMSON(Color(0xFFFF86A4), Color(0xFFC81545), Color(0xFF760A2A)),
    CORAL(Color(0xFFFFC1C0), Color(0xFFFF5A6E), Color(0xFFA01530)),
}

// Draw one hand-built top-down ROSE centred in this DrawScope: concentric rings of broad,
// rounded, overlapping petals (rounded ovals, rx ≈ 0.68·ry, pointing outward), getting
// smaller toward the middle, finished with a small rolled-bud center dot. No golden disc.
// Outer/mid rings are LIGHT→MID radial-shaded; inner/center rings are MID→DEEP (darker).
// Mirrors the web's rose <Flower>.
fun DrawScope.drawFlower(hue: FlowerHue, petals: Int = 13) {
    val w = size.width
    val cx = w * 0.5f
    val cy = w * 0.5f
    val half = w * 0.5f

    // One ring of broad rounded petals pointing outward from the center.
    // ryFrac/offsetFrac are fractions of the half-size; deep=true uses the MID→DEEP gradient.
    fun ring(count: Int, ryFrac: Float, offsetFrac: Float, rotOffsetDeg: Float, deep: Boolean) {
        val ry = half * ryFrac
        val rx = ry * 0.68f
        val ovalCenterDist = half * offsetFrac   // petal center distance outward from middle
        val inner = if (deep) hue.mid else hue.light
        val outer = if (deep) hue.deep else hue.mid
        for (k in 0 until count) {
            val angDeg = rotOffsetDeg + (360f / count) * k
            rotateRad(Math.toRadians(angDeg.toDouble()).toFloat(), pivot = Offset(cx, cy)) {
                val ovalW = rx * 2f
                val ovalH = ry * 2f
                // Petal center sits above the middle (pointing "up"); the rotate fans it out.
                val petalCy = cy - ovalCenterDist
                val topLeft = Offset(cx - ovalW / 2f, petalCy - ovalH / 2f)
                drawOval(
                    brush = Brush.radialGradient(
                        colorStops = arrayOf(0f to inner, 1f to outer),
                        center = Offset(cx, petalCy + ovalH * 0.28f),
                        radius = ovalH * 0.72f,
                    ),
                    topLeft = topLeft,
                    size = Size(ovalW, ovalH),
                    alpha = 0.96f,
                )
            }
        }
    }

    // Outermost first so inner rings overlap on top.
    ring(8, ryFrac = 0.38f, offsetFrac = 0.20f, rotOffsetDeg = 0f, deep = false)
    ring(7, ryFrac = 0.32f, offsetFrac = 0.26f, rotOffsetDeg = 360f / 7f / 2f, deep = false)
    ring(6, ryFrac = 0.26f, offsetFrac = 0.32f, rotOffsetDeg = 360f / 6f / 3f, deep = true)
    ring(5, ryFrac = 0.20f, offsetFrac = 0.38f, rotOffsetDeg = 360f / 5f / 2f, deep = true)

    // Small rolled-bud center dot.
    drawCircle(
        brush = Brush.radialGradient(
            colorStops = arrayOf(0f to hue.mid, 1f to hue.deep),
            center = Offset(cx, cy),
            radius = half * 0.14f,
        ),
        radius = half * 0.12f,
        center = Offset(cx, cy),
    )
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

// GARDEN only: ~5 small vector flowers slowly drifting DOWN the full screen, looping,
// staggered, with a gentle horizontal sway + slow rotation, semi-transparent. Reuses the
// shared drawFlower at small size. Mirrors the web app's drifting-petal layer. Non-interactive.
@Composable
fun GardenPetalOverlay(modifier: Modifier = Modifier) {
    data class Petal(
        val hue: FlowerHue, val sizeDp: Int, val xFrac: Float,
        val fallMs: Int, val swayMs: Int, val spinMs: Int, val phase: Float, val petals: Int,
    )
    val petalDefs = listOf(
        Petal(FlowerHue.ROSE,    38, 0.14f, 16000, 5200, 20000, 0.00f, 13),
        Petal(FlowerHue.RED,     30, 0.38f, 13000, 4300, 17000, 0.30f, 15),
        Petal(FlowerHue.BLUSH,   46, 0.58f, 19000, 6100, 24000, 0.55f, 13),
        Petal(FlowerHue.CORAL,   34, 0.78f, 14500, 4800, 19000, 0.18f, 14),
        Petal(FlowerHue.CRIMSON, 32, 0.90f, 17500, 5600, 22000, 0.72f, 14),
    )
    val t = rememberInfiniteTransition(label = "petals")
    Box(modifier.fillMaxSize().alpha(0.55f)) {
        for (p in petalDefs) {
            val fall by t.animateFloat(
                0f, 1f,
                infiniteRepeatable(tween(p.fallMs, easing = LinearEasing), RepeatMode.Restart),
                label = "fall",
            )
            val sway by t.animateFloat(
                -1f, 1f,
                infiniteRepeatable(tween(p.swayMs, easing = LinearEasing), RepeatMode.Reverse),
                label = "sway",
            )
            val spin by t.animateFloat(
                0f, 360f,
                infiniteRepeatable(tween(p.spinMs, easing = LinearEasing), RepeatMode.Restart),
                label = "spin",
            )
            // Stagger each petal's fall progress so they don't drop in lockstep.
            val prog = (fall + p.phase).let { it - kotlin.math.floor(it) }
            BoxWithConstraints {
                val h = maxHeight
                Canvas(
                    Modifier
                        .align(Alignment.TopStart)
                        .offset(
                            x = (maxWidth * p.xFrac) + (sway * 18).dp,
                            y = (-(p.sizeDp).dp) + (h + p.sizeDp.dp) * prog,
                        )
                        .size(p.sizeDp.dp)
                        .rotate(spin),
                ) { drawFlower(p.hue, p.petals) }
            }
        }
    }
}

// GARDEN-only soft BACKGROUND wallpaper: several large vector flowers at ~50% opacity,
// gently swaying, behind the foreground content. Non-interactive. Mirrors the web GardenFX
// bg-flower layer (varied hue/size/position).
@Composable
fun GardenFlowerBackdrop(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().alpha(0.5f)) {
        SwayFlower(FlowerHue.ROSE, sizeDp = 320, align = Alignment.TopStart, xDp = -90, yDp = -60, swayMs = 9000, reverse = false)
        SwayFlower(FlowerHue.RED, sizeDp = 230, align = Alignment.TopEnd, xDp = 60, yDp = 150, swayMs = 11000, reverse = true, petals = 15)
        SwayFlower(FlowerHue.BLUSH, sizeDp = 260, align = Alignment.BottomStart, xDp = 90, yDp = 60, swayMs = 13000, reverse = false)
        SwayFlower(FlowerHue.CORAL, sizeDp = 185, align = Alignment.CenterStart, xDp = -45, yDp = 40, swayMs = 10000, reverse = true)
        SwayFlower(FlowerHue.CRIMSON, sizeDp = 200, align = Alignment.Center, xDp = 30, yDp = -80, swayMs = 12000, reverse = false, petals = 14)
    }
}
