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
import androidx.compose.runtime.mutableStateOf
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

// Lets a screen temporarily hide the app-wide electric backdrop (e.g. the book page
// stays calm until playback starts). Reset to false when leaving that screen.
object ElectricState {
    var suppressed by mutableStateOf(false)
}

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

    // Strobing lightning bolts — sparse: fewer bolts + slower, briefer strikes (~¼ as much).
    val bolts = max(1, (2.5f * intensity).toInt())
    for (k in 0 until bolts) {
        val phase = k * 1.7f
        val strobe = max(0f, sin(t * (0.9f + (k % 3) * 0.35f) + phase)).pow(12)
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

// A natural lightning bolt: a fractal (midpoint-displaced) channel rendered as stacked
// glow layers up to a white-hot core, with a few jagged forks branching off.
private fun DrawScope.drawBolt(a: Offset, b: Offset, t: Float, seed: Int, alpha: Float) {
    val len = max(1f, hypot(b.x - a.x, b.y - a.y))
    val pts = jagged(a, b, len * 0.13f, 5, seed, t)
    strokeBolt(pts, alpha, 1f)

    val dir0 = kotlin.math.atan2(b.y - a.y, b.x - a.x)
    val forks = 2 + seed % 2
    for (k in 0 until forks) {
        val idx = minOf(pts.size - 2, (pts.size * (0.35f + 0.2f * k)).toInt())
        if (idx <= 0) continue
        val base = pts[idx]
        val dir = dir0 + (if (k % 2 == 0) 0.8f else -0.8f) + kotlin.math.sin(t * 2f + (seed + k)) * 0.25f
        val fl = len * (0.24f - 0.05f * k)
        val end = Offset(base.x + cos(dir) * fl, base.y + sin(dir) * fl)
        strokeBolt(jagged(base, end, fl * 0.2f, 3, seed * 7 + k, t), alpha * 0.8f, 0.6f)
    }
}

// Recursive midpoint displacement → a jagged, organic lightning channel.
private fun jagged(a: Offset, b: Offset, rough: Float, levels: Int, seed: Int, t: Float): List<Offset> {
    var pts = mutableListOf(a, b)
    var disp = rough
    repeat(levels) { level ->
        val next = ArrayList<Offset>(pts.size * 2)
        next.add(pts[0])
        for (i in 0 until pts.size - 1) {
            val p0 = pts[i]; val p1 = pts[i + 1]
            val sx = p1.x - p0.x; val sy = p1.y - p0.y
            val sl = max(1f, hypot(sx, sy))
            val nx = -sy / sl; val ny = sx / sl
            val h = sin(seed * 12.9f + (i + level * 7) * 78.233f + t * 2.5f)
            val off = h * disp
            next.add(Offset((p0.x + p1.x) / 2 + nx * off, (p0.y + p1.y) / 2 + ny * off))
            next.add(p1)
        }
        pts = next
        disp *= 0.52f
    }
    return pts
}

// Stacked strokes: wide soft halo → blue glow → bright channel → white-hot core.
private fun DrawScope.strokeBolt(pts: List<Offset>, alpha: Float, scale: Float) {
    if (pts.size < 2) return
    val path = Path().apply {
        moveTo(pts[0].x, pts[0].y); for (i in 1 until pts.size) lineTo(pts[i].x, pts[i].y)
    }
    val cap = StrokeCap.Round; val join = StrokeJoin.Round; val plus = BlendMode.Plus
    drawPath(path, Theme.verdigris.copy(alpha = 0.10f * alpha),
        style = Stroke(width = 16f * scale, cap = cap, join = join), blendMode = plus)
    drawPath(path, Theme.verdigris.copy(alpha = 0.32f * alpha),
        style = Stroke(width = 7f * scale, cap = cap, join = join), blendMode = plus)
    drawPath(path, Color(0xFF9FE0FF).copy(alpha = 0.9f * alpha),
        style = Stroke(width = 3f * scale, cap = cap, join = join), blendMode = plus)
    drawPath(path, Color(0xFFFFFFFF).copy(alpha = 0.95f * alpha),
        style = Stroke(width = 1.3f * scale, cap = cap, join = join), blendMode = plus)
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
