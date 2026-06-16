package app.chronicler

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

private val SPARK = Color(0xFFC8F0FF)   // icy electric-blue lightning core

// Full-screen animated electricity behind content: roving lightning bolts that strobe
// + flicker, plus drifting glow nodes. Additive (Plus) blend so the app looks charged.
// Mirrors iOS ElectricBackground. Drives a frame clock via withFrameNanos.
@Composable
fun ElectricBackground(intensity: Float = 1f, modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) {
            val now = withFrameNanos { it }
            t = (now - start) / 1_000_000_000f
        }
    }
    Canvas(modifier) { drawField(t, intensity) }
}

private fun DrawScope.drawField(t: Float, intensity: Float) {
    val w = size.width; val h = size.height

    // Drifting soft glow nodes — ambient charge.
    val nodes = max(1, (3 * intensity).toInt())
    for (k in 0 until nodes) {
        val p = k * 2.3f
        val gx = w * (0.5f + 0.42f * sin(t * 0.19f + p))
        val gy = h * (0.5f + 0.42f * cos(t * 0.15f + p * 1.1f))
        val pulse = 0.4f + 0.6f * (0.5f + 0.5f * sin(t * 1.5f + p))
        val r = 130f * pulse
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Theme.verdigris.copy(alpha = 0.12f * pulse * intensity),
                                 Theme.verdigris.copy(alpha = 0f)),
                center = Offset(gx, gy), radius = r),
            radius = r, center = Offset(gx, gy))
    }

    // Strobing lightning bolts.
    val bolts = max(2, (6 * intensity).toInt())
    for (k in 0 until bolts) {
        val phase = k * 1.7f
        val strobe = max(0f, sin(t * (2.2f + (k % 3) * 0.6f) + phase)).pow(6)
        val flick = 0.55f + 0.45f * sin(t * 42f + phase)
        val alpha = strobe * (0.35f + 0.65f * flick) * min(1.3f, intensity)
        if (alpha < 0.02f) continue
        val a = Offset(w * (0.5f + 0.52f * sin(t * 0.13f + phase)),
                       h * (0.10f + 0.12f * sin(t * 0.21f + phase * 1.3f)))
        val b = Offset(w * (0.5f + 0.52f * sin(t * 0.11f + phase + 2f)),
                       h * (0.80f + 0.18f * sin(t * 0.17f + phase * 0.7f)))
        drawBolt(a, b, t, k, alpha)
    }
}

private fun DrawScope.drawBolt(a: Offset, b: Offset, t: Float, seed: Int, alpha: Float) {
    val segs = 16
    val dx = b.x - a.x; val dy = b.y - a.y
    val len = max(1f, hypot(dx, dy))
    val nx = -dy / len; val ny = dx / len
    val pts = ArrayList<Offset>(segs + 1)
    for (i in 0..segs) {
        val f = i / segs.toFloat()
        val env = sin(f * Math.PI.toFloat())
        val j = sin(t * 9f + seed * 3.1f + f * 13f) * 46f * env +
                sin(t * 23f + seed + f * 31f) * 18f * env
        pts.add(Offset(a.x + dx * f + nx * j, a.y + dy * f + ny * j))
    }
    val path = Path().apply {
        moveTo(pts[0].x, pts[0].y)
        for (i in 1 until pts.size) lineTo(pts[i].x, pts[i].y)
    }
    drawPath(path, Theme.verdigris.copy(alpha = 0.25f * alpha),
        style = Stroke(width = 10f, cap = StrokeCap.Round, join = StrokeJoin.Round), blendMode = BlendMode.Plus)
    drawPath(path, Theme.verdigris.copy(alpha = 0.55f * alpha),
        style = Stroke(width = 4f, cap = StrokeCap.Round, join = StrokeJoin.Round), blendMode = BlendMode.Plus)
    drawPath(path, SPARK.copy(alpha = 0.95f * alpha),
        style = Stroke(width = 1.6f, cap = StrokeCap.Round, join = StrokeJoin.Round), blendMode = BlendMode.Plus)
    if (seed % 2 == 0) {
        val m = pts[segs * 2 / 3]
        val fa = kotlin.math.atan2(dy, dx) + if (seed % 4 == 0) 0.7f else -0.7f
        val fl = len * 0.18f
        val fork = Path().apply {
            moveTo(m.x, m.y); lineTo(m.x + cos(fa) * fl, m.y + sin(fa) * fl)
        }
        drawPath(fork, SPARK.copy(alpha = 0.8f * alpha),
            style = Stroke(width = 1.4f, cap = StrokeCap.Round), blendMode = BlendMode.Plus)
    }
}

// A light electric "charge" — faint pulsing border. For elements that should feel
// energized without the full panel treatment (e.g. every chapter row). Mirrors iOS charged().
fun Modifier.charged(): Modifier = composed {
    val shape = RoundedCornerShape(4.dp)
    val tr = rememberInfiniteTransition(label = "charge")
    val p by tr.animateFloat(
        initialValue = 0.12f, targetValue = 0.42f,
        animationSpec = infiniteRepeatable(tween(2000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "c")
    this
        .shadow((3f + 8f * p).dp, shape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
        .border(1.dp, Theme.verdigris.copy(alpha = p), shape)
}
