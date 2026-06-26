package app.chronicler

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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

// Static Tesla backdrop: a dark blue-black field with a subtle cyan radial glow centred
// high, plus a faint circuit-grid of thin cyan lines. Drawn once (no animation) behind the
// animated lightning so the whole app reads as cold/electric/glassy. TESLA only.
@Composable
fun TeslaBackdrop(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width; val h = size.height
        // Base wash so edges stay deep blue-black even over the app bg.
        drawRect(Color(0xFF05080F))
        // Cyan radial glow, upper-centre.
        val gc = Offset(w * 0.5f, h * 0.30f)
        val gr = hypot(w, h) * 0.7f
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFF2BC4FF).copy(alpha = 0.16f), Color(0x002BC4FF)),
                center = gc, radius = gr),
            radius = gr, center = gc)
        // Faint circuit grid.
        val step = 64f
        val line = Color(0xFF2BC4FF).copy(alpha = 0.05f)
        var x = 0f
        while (x <= w) { drawLine(line, Offset(x, 0f), Offset(x, h), strokeWidth = 1f); x += step }
        var y = 0f
        while (y <= h) { drawLine(line, Offset(0f, y), Offset(w, y), strokeWidth = 1f); y += step }
        // A few brighter node dots at random-ish grid intersections to suggest circuitry.
        val node = Color(0xFF2BC4FF).copy(alpha = 0.18f)
        for (i in 0 until 9) {
            val nx = ((i * 3 + 1) % ((w / step).toInt().coerceAtLeast(1))) * step
            val ny = ((i * 5 + 2) % ((h / step).toInt().coerceAtLeast(1))) * step
            drawCircle(node, radius = 2.2f, center = Offset(nx, ny))
        }
    }
}

// Calm GARDEN backdrop: a dark green field with a single soft green radial glow centred
// high. No lightning, no circuit grid, no animation — verdant and organic. GARDEN only.
@Composable
fun GardenBackdrop(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width; val h = size.height
        // Deep green field wash.
        drawRect(Color(0xFF0B1410))
        // Soft green radial bloom, upper-centre.
        val gc = Offset(w * 0.5f, h * 0.32f)
        val gr = hypot(w, h) * 0.75f
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFF7CC24A).copy(alpha = 0.14f), Color(0x007CC24A)),
                center = gc, radius = gr),
            radius = gr, center = gc)
        // A second, lower bloom in floral pink for warmth — very faint.
        val pc = Offset(w * 0.5f, h * 0.85f)
        val pr = hypot(w, h) * 0.5f
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(Color(0xFFFF8FB8).copy(alpha = 0.06f), Color(0x00FF8FB8)),
                center = pc, radius = pr),
            radius = pr, center = pc)
    }
}

// Dark-Academia backdrop: espresso field, warm brass lamplight from above, a faint green
// pool low, and rain streaking down the glass. Animated via a frame clock. ACADEMIA only.
@Composable
fun AcademiaBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        drawRect(Color(0xFF161009))
        // Warm brass lamplight bloom from the top.
        val gc = Offset(w * 0.5f, h * 0.12f); val gr = hypot(w, h) * 0.78f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFFC39A4E).copy(alpha = 0.13f), Color(0x00C39A4E)),
            center = gc, radius = gr), radius = gr, center = gc)
        // Faint forest-green pool low.
        val pc = Offset(w * 0.5f, h * 0.92f); val pr = hypot(w, h) * 0.45f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFF4F8A52).copy(alpha = 0.08f), Color(0x004F8A52)),
            center = pc, radius = pr), radius = pr, center = pc)
        // Slanted rain — many thin streaks falling at varied speed (deterministic from t).
        val slant = 0.2f; val span = h + 200f
        for (i in 0 until 90) {
            val fx = ((i * 73) % 1000) / 1000f
            val speed = 680f + ((i * 37) % 420)
            val len = 22f + ((i * 13) % 26)
            val x0 = fx * (w + 140f) - 70f
            val y = ((t * speed + i * 57f) % span) - 120f
            drawLine(Color(0xFFD4C29A).copy(alpha = 0.22f),
                Offset(x0, y), Offset(x0 + slant * len, y + len),
                strokeWidth = 1.2f, blendMode = BlendMode.Plus)
        }
    }
}

// Blackletter-Noir backdrop: near-black field, a low ox-blood ember, slow drifting cold
// fog, and a heavy cathedral vignette. Animated via a frame clock. NOIR only.
@Composable
fun NoirBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        drawRect(Color(0xFF060608))
        // Low ox-blood ember.
        val ec = Offset(w * 0.5f, h * 1.02f); val er = hypot(w, h) * 0.5f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFF9E1B22).copy(alpha = 0.13f), Color(0x009E1B22)),
            center = ec, radius = er), radius = er, center = ec)
        // Slow drifting banks of cold fog.
        for (k in 0 until 4) {
            val p = k * 1.9f
            val cx = w * (0.5f + 0.55f * sin(t * 0.03f + p))
            val cy = h * (0.16f + 0.22f * k)
            val r = hypot(w, h) * 0.32f
            drawCircle(brush = Brush.radialGradient(
                colors = listOf(Color(0xFF9A9EAA).copy(alpha = 0.09f), Color(0x009A9EAA)),
                center = Offset(cx, cy), radius = r), radius = r, center = Offset(cx, cy),
                blendMode = BlendMode.Plus)
        }
        // Heavy vignette — transparent centre to near-black edges.
        val vc = Offset(w * 0.5f, h * 0.45f); val vr = hypot(w, h) * 0.62f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0x00000000), Color(0xB8000000)),
            center = vc, radius = vr), radius = vr, center = vc)
    }
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
    if (Theme.themeMode == ThemeMode.GARDEN) {
        // No electricity, no glass: a steady, soft green edge with generous 16.dp corners.
        val shape = RoundedCornerShape(16.dp)
        this
            .shadow(4.dp, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .border(1.dp, Theme.borderBrass.copy(alpha = 0.3f), shape)
    } else if (Theme.themeMode == ThemeMode.STEAMPUNK) {
        // No electricity, no glass: a steady, faint brass edge with tight 2.dp corners.
        val shape = RoundedCornerShape(2.dp)
        this
            .shadow(4.dp, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .border(1.dp, Theme.borderBrass.copy(alpha = 0.35f), shape)
    } else if (Theme.themeMode == ThemeMode.ACADEMIA) {
        // No electricity: a steady brass-green edge with softly-squared 6.dp corners.
        val shape = RoundedCornerShape(6.dp)
        this
            .shadow(4.dp, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .border(1.dp, Theme.borderBrass.copy(alpha = 0.32f), shape)
    } else if (Theme.themeMode == ThemeMode.NOIR) {
        // No electricity: a steady tarnished-silver edge with sharp 0.dp corners.
        val shape = RoundedCornerShape(0.dp)
        this
            .shadow(4.dp, shape, spotColor = Color.Black, ambientColor = Color.Black)
            .border(1.dp, Theme.borderBrass.copy(alpha = 0.35f), shape)
    } else {
        // Glassy Tesla edge: soft 10.dp corners, faint translucent cyan fill + pulsing border.
        val shape = RoundedCornerShape(10.dp)
        val tr = rememberInfiniteTransition(label = "charge")
        val p by tr.animateFloat(
            initialValue = 0.12f, targetValue = 0.42f,
            animationSpec = infiniteRepeatable(tween(2000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "c")
        this
            .shadow((3f + 8f * p).dp, shape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
            .background(Theme.surface.copy(alpha = 0.22f), shape)
            .border(1.dp, Theme.verdigris.copy(alpha = 0.3f + p), shape)
    }
}
