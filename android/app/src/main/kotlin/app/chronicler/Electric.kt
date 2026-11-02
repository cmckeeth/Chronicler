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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import kotlin.math.abs
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
        drawRect(Color(0xFF040406))
        // Blood rose-window glow high above.
        val rc = Offset(w * 0.5f, h * 0.08f); val rr = hypot(w, h) * 0.42f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFFA8121B).copy(alpha = 0.18f), Color(0x00A8121B)),
            center = rc, radius = rr), radius = rr, center = rc)
        // Low ox-blood ember seeping from the floor.
        val ec = Offset(w * 0.5f, h * 1.04f); val er = hypot(w, h) * 0.55f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFFA8121B).copy(alpha = 0.17f), Color(0x00A8121B)),
            center = ec, radius = er), radius = er, center = ec)
        // Thick, slow drifting banks of cold fog.
        for (k in 0 until 6) {
            val p = k * 1.6f
            val cx = w * (0.5f + 0.6f * sin(t * 0.022f + p))
            val cy = h * (0.1f + 0.16f * k)
            val r = hypot(w, h) * 0.36f
            drawCircle(brush = Brush.radialGradient(
                colors = listOf(Color(0xFF9A9EAA).copy(alpha = 0.13f),
                                 Color(0xFF6E7280).copy(alpha = 0.05f), Color(0x009A9EAA)),
                center = Offset(cx, cy), radius = r), radius = r, center = Offset(cx, cy),
                blendMode = BlendMode.Plus)
        }
        // Embers rising from the dark — faint glowing red motes that fade in and out.
        val span = h + 80f
        for (i in 0 until 22) {
            val fx = ((i * 89) % 1000) / 1000f
            val speed = 55f + ((i * 31) % 70)
            val sway = sin(t * 0.8f + i) * 18f
            val x = fx * w + sway
            val prog = (t * speed + i * 47f) % span
            val y = h - prog
            val life = 1f - prog / span
            val a = (sin(life * Math.PI.toFloat())).coerceAtLeast(0f) * 0.9f
            val er2 = (1.5f + (i % 3)) * 3f
            drawCircle(brush = Brush.radialGradient(
                colors = listOf(Color(0xFFE0464D).copy(alpha = a), Color(0x00E0464D)),
                center = Offset(x, y), radius = er2), radius = er2, center = Offset(x, y),
                blendMode = BlendMode.Plus)
        }
        // Heavy cathedral tunnel vignette — transparent centre to near-black edges.
        val vc = Offset(w * 0.5f, h * 0.45f); val vr = hypot(w, h) * 0.6f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0x00000000), Color(0xD6000000)),
            center = vc, radius = vr), radius = vr, center = vc)
    }
}

// WEST-only backdrop: a low sun burning on the horizon, mesas and saguaros cut flat
// against it, dust hanging in the air, and tumbleweeds rolling across the flats.
// Mirrors the iOS MesaSkyline + DustOverlay + TumbleweedOverlay.
@Composable
fun WestBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        drawRect(Color(0xFF150E08))

        // Setting sun burning just below the horizon.
        val sc = Offset(w * 0.5f, h * 0.82f); val sr = hypot(w, h) * 0.5f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0xFFF08A30).copy(alpha = 0.42f),
                            Color(0xFF9C4418).copy(alpha = 0.16f), Color(0x00F08A30)),
            center = sc, radius = sr), radius = sr, center = sc)
        // Dusk vignette closing the corners.
        val vc = Offset(w * 0.5f, h * 0.5f); val vr = hypot(w, h) * 0.62f
        drawCircle(brush = Brush.radialGradient(
            colors = listOf(Color(0x00000000), Color(0x8C000000)),
            center = vc, radius = vr), radius = vr, center = vc)

        // Mesas: flat-topped blocks with sloped shoulders, black against the sun.
        val silhouette = Color(0xFF1A0F07)
        fun mesa(cx: Float, width: Float, height: Float, shade: Float) {
            val l = cx - width / 2; val r = cx + width / 2; val top = h - height
            val p = Path().apply {
                moveTo(l, h); lineTo(l + width * 0.18f, top)
                lineTo(r - width * 0.14f, top); lineTo(r, h); close()
            }
            drawPath(p, silhouette.copy(alpha = shade))
        }
        mesa(w * 0.10f, w * 0.40f, h * 0.085f, 0.85f)
        mesa(w * 0.55f, w * 0.34f, h * 0.062f, 0.80f)
        mesa(w * 0.95f, w * 0.32f, h * 0.10f, 0.90f)

        // Saguaros: trunk + two raised arms.
        fun saguaro(cx: Float, scale: Float) {
            val trunkW = 11f * scale * density; val trunkH = 96f * scale * density
            val armW = 8f * scale * density
            fun bar(x: Float, y: Float, bw: Float, bh: Float) =
                drawRoundRect(color = silhouette.copy(alpha = 0.85f),
                    topLeft = Offset(x, y), size = Size(bw, bh),
                    cornerRadius = CornerRadius(armW / 2, armW / 2))
            bar(cx - trunkW / 2, h - trunkH, trunkW, trunkH)
            bar(cx - 30f * scale * density, h - trunkH * 0.62f, armW, trunkH * 0.42f)
            bar(cx - 30f * scale * density, h - trunkH * 0.62f, 30f * scale * density, armW)
            bar(cx + 22f * scale * density, h - trunkH * 0.78f, armW, trunkH * 0.34f)
            bar(cx, h - trunkH * 0.78f, 26f * scale * density, armW)
        }
        saguaro(w * 0.30f, 0.62f)
        saguaro(w * 0.78f, 0.45f)

        // Flat desert floor closing off the bottom.
        drawRect(silhouette.copy(alpha = 0.9f),
            topLeft = Offset(0f, h - 10f * density), size = Size(w, 40f * density))

        // Fine dust hanging in the low sun.
        for (i in 0 until 70) {
            val fy = ((i * 61) % 1000) / 1000f
            val speed = 12f + ((i * 29) % 26)
            val x = ((t * speed + i * 91f) % (w + 60f)) - 30f
            val y = fy * h + sin(t * 0.6f + i) * 6f
            val r = (1f + (i % 3)) * density
            drawCircle(Color(0xFFE8C489).copy(alpha = 0.16f), radius = r, center = Offset(x, y),
                blendMode = BlendMode.Plus)
        }

        // Tumbleweeds: tangled balls of brush rolling and hopping across the flats.
        for (k in 0 until 3) {
            val period = 17f + k * 7f
            val phase = ((t / period) + k * 0.37f) % 1f
            val radius = (15f - k * 3f) * density
            val x = phase * (w + 160f * density) - 80f * density
            val ground = h - (14f + k * 16f) * density
            val hop = abs(sin(phase * Math.PI.toFloat() * 9f)) * (18f - k * 4f) * density
            val cy = ground - hop - radius
            val spin = phase * Math.PI.toFloat() * 2f * 7f
            for (ring in 0 until 4) {
                val ringScale = 0.45f + 0.2f * ring
                val tilt = spin * (if (ring % 2 == 0) 1f else -0.8f) + ring
                val steps = 13
                val p = Path()
                for (j in 0..steps) {
                    val a = tilt + j * (2f * Math.PI.toFloat() / steps)
                    val jitter = 0.72f + 0.5f * abs(sin(j * 3.1f + ring * 1.7f + k))
                    val rr = radius * ringScale * jitter
                    val px = x + rr * cos(a); val py = cy + rr * sin(a) * 0.9f
                    if (j == 0) p.moveTo(px, py) else p.lineTo(px, py)
                }
                p.close()
                drawPath(p, Color(0xFF8A6231).copy(alpha = 0.75f),
                    style = Stroke(width = 1.2f * density))
            }
        }
    }
}


// NEON-only backdrop: a banded sun on the horizon, a wireframe grid scrolling toward the
// viewer in perspective, palm silhouettes, and CRT scanlines with a slow brightness roll.
// Mirrors the iOS NeonSunGrid + ScanlineOverlay.
@Composable
fun NeonBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val horizon = h * 0.62f

        // Sky: indigo bleeding to magenta at the horizon.
        drawRect(Brush.verticalGradient(
            listOf(Color(0xFF2A0B4A), Color(0xFF7A1170).copy(alpha = 0.65f),
                   Color(0xFFFF4FD8).copy(alpha = 0.22f)),
            startY = 0f, endY = horizon), size = Size(w, horizon))

        // Sun: a gradient disc with widening horizontal band gaps punched out of it.
        val sunR = minOf(w, h) * 0.20f
        val cx = w / 2f; val cy = horizon - sunR * 0.28f
        drawCircle(brush = Brush.verticalGradient(
            listOf(Color(0xFFFFE14F), Color(0xFFFF4FD8), Color(0xFF9C2BFF)),
            startY = cy - sunR, endY = cy + sunR), radius = sunR, center = Offset(cx, cy))
        var band = 0f; var i = 0
        while (band < sunR * 2) {
            val gap = 3f + i * 1.5f
            drawRect(Color(0xFF150726).copy(alpha = 0.9f),
                topLeft = Offset(cx - sunR, cy - sunR + band), size = Size(sunR * 2, gap * 0.55f))
            band += gap + 6f; i++
        }
        drawCircle(Color(0xFFFF8CE6).copy(alpha = 0.9f), radius = sunR, center = Offset(cx, cy),
            style = Stroke(width = 2f))

        // Ground.
        drawRect(Brush.verticalGradient(listOf(Color(0xFF1B0733), Color(0xFF0D0418)),
            startY = horizon, endY = h), topLeft = Offset(0f, horizon), size = Size(w, h - horizon))

        val grid = Color(0xFF22E0FF)
        // Rows: squared spacing bunches them at the horizon; the set scrolls forward.
        val phase = (t / 2.6f) % 1f
        for (k in 0 until 16) {
            val p = (k + phase) / 16f
            val y = horizon + (h - horizon) * p * p
            if (y > h) continue
            drawLine(grid.copy(alpha = 0.10f + 0.5f * p), Offset(0f, y), Offset(w, y),
                strokeWidth = 0.6f + 1.4f * p)
        }
        // Verticals fanning from the vanishing point.
        for (k in -9..9) {
            drawLine(grid.copy(alpha = 0.30f), Offset(cx, horizon),
                Offset(cx + k * (w / 6f), h), strokeWidth = 1f)
        }
        drawLine(Color(0xFFFF8CE6).copy(alpha = 0.85f), Offset(0f, horizon), Offset(w, horizon),
            strokeWidth = 2f)

        // Palms: leaning trunk plus drooping fronds.
        fun palm(baseX: Float, scale: Float, flip: Float) {
            val baseY = horizon + 6f
            val hgt = minOf(w, h) * 0.26f * scale
            val topX = baseX + 16f * scale * flip; val topY = baseY - hgt
            val trunk = Path().apply {
                moveTo(baseX, baseY)
                quadraticBezierTo(baseX + 2f * scale * flip, baseY - hgt * 0.6f, topX, topY)
            }
            drawPath(trunk, Color(0xFF120423), style = Stroke(width = 4f * scale))
            for (f in 0 until 6) {
                val a = f / 5f * Math.PI.toFloat() - Math.PI.toFloat() * 0.08f
                val frond = Path().apply {
                    moveTo(topX, topY)
                    quadraticBezierTo(topX + cos(a) * 22f * scale, topY - 14f * scale,
                        topX + cos(a) * 34f * scale,
                        topY + abs(sin(a)) * 8f * scale + 16f * scale)
                }
                drawPath(frond, Color(0xFF120423), style = Stroke(width = 3f * scale))
            }
        }
        palm(w * 0.13f, 1.0f, 1f)
        palm(w * 0.88f, 0.85f, -1f)

        // CRT scanlines + a bright band rolling down every ~7s.
        var y = 0f
        while (y < h) { drawRect(Color.Black.copy(alpha = 0.18f), Offset(0f, y), Size(w, 1f)); y += 3f }
        val rollY = ((t / 7f) % 1f) * h
        drawRect(Brush.verticalGradient(
            listOf(Color.Transparent, Color.White.copy(alpha = 0.05f), Color.Transparent),
            startY = rollY - 40f, endY = rollY + 40f),
            topLeft = Offset(0f, rollY - 40f), size = Size(w, 80f))
    }
}

// FORGE-only backdrop: a churning molten pool along the bottom, glowing fissures cracking
// up through the rock, and sparks spitting upward. Mirrors iOS LavaFissures + SparkOverlay.
@Composable
fun ForgeBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        drawRect(Color(0xFF0B0705))
        // Heat rising from below, then a vignette closing the corners.
        val hc = Offset(w * 0.5f, h * 1.02f); val hr = hypot(w, h) * 0.62f
        drawCircle(brush = Brush.radialGradient(
            listOf(Color(0xFFFF6A12).copy(alpha = 0.34f), Color(0xFF8C1F04).copy(alpha = 0.14f),
                   Color(0x00FF6A12)), center = hc, radius = hr), radius = hr, center = hc)
        val vc = Offset(w * 0.5f, h * 0.5f); val vr = hypot(w, h) * 0.6f
        drawCircle(brush = Brush.radialGradient(listOf(Color(0x00000000), Color(0x9E000000)),
            center = vc, radius = vr), radius = vr, center = vc)

        val surface = h * 0.96f
        // Fissures: shorter cracks near the pool, unevenly spaced, each breathing on its
        // own period so the rock looks alive rather than animated in lockstep.
        val fissureX = floatArrayOf(0.06f, 0.17f, 0.23f, 0.38f, 0.52f, 0.61f, 0.74f, 0.83f, 0.94f)
        fissureX.forEachIndexed { k, fxFrac ->
            val fx = w * fxFrac
            val period = 2.2f + (k % 4) * 0.9f
            val pulse = 0.35f + 0.65f * (0.5f - 0.5f * cos(t / period * 2f * Math.PI.toFloat()))
            val len = h * (0.05f + 0.05f * (k % 4))
            val crack = Path().apply {
                moveTo(fx, surface)
                var yy = surface; var xx = fx; var seg = 0
                while (yy > surface - len) {
                    yy -= 14f; xx += sin(seg * 2.3f + k) * 9f
                    lineTo(xx, yy); seg++
                }
            }
            drawPath(crack, Color(0xFFFF6A12).copy(alpha = 0.22f * pulse),
                style = Stroke(width = 9f, cap = StrokeCap.Round))
            drawPath(crack, Color(0xFFFFB04A).copy(alpha = 0.75f * pulse),
                style = Stroke(width = 2.6f, cap = StrokeCap.Round))
            drawPath(crack, Color(0xFFFFE9A8).copy(alpha = 0.9f * pulse),
                style = Stroke(width = 1f, cap = StrokeCap.Round))
        }

        // Molten pool: a wavy top edge over a hot gradient.
        val pool = Path().apply {
            moveTo(0f, h)
            var x = 0f
            while (x <= w) {
                lineTo(x, surface + sin(x / 70f + t * 0.7f) * 7f + sin(x / 33f - t * 1.1f) * 4f)
                x += 6f
            }
            lineTo(w, h); close()
        }
        drawPath(pool, Brush.verticalGradient(
            listOf(Color(0xFFFFD23F), Color(0xFFFF6A12), Color(0xFFB52200)),
            startY = surface - 10f, endY = h))
        drawPath(pool, Color(0xFFFFE9A8).copy(alpha = 0.8f), style = Stroke(width = 1.5f))

        // Sparks: rising fast, cooling white → red, fading out.
        val span = h * 0.8f
        for (i in 0 until 40) {
            val fx = ((i * 83) % 1000) / 1000f
            val speed = 110f + ((i * 47) % 130)
            val prog = (t * speed + i * 37f) % span
            val life = 1f - prog / span
            val x = fx * w + sin(t * 1.6f + i) * 14f
            val y = surface - prog
            val r = 1f + (i % 3)
            drawCircle(Color(0xFFFF3C00).copy(alpha = life * 0.5f), radius = r * 1.3f,
                center = Offset(x, y), blendMode = BlendMode.Plus)
            drawCircle(Color(0xFFFFE9A8).copy(alpha = life * 0.95f), radius = r * 0.5f,
                center = Offset(x, y), blendMode = BlendMode.Plus)
        }
    }
}

// RANSOM-only backdrop: the page itself — halftone dot screen, toner streaks, and two
// strips of tape at the corners. Static, because photocopies don't animate.
@Composable
fun RansomBackdrop(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width; val h = size.height
        drawRect(Color(0xFFE8E4D9))
        // Halftone, denser toward the edges like a bad copy.
        var y = 0f; var row = 0
        while (y < h) {
            var x = if (row % 2 == 0) 0f else 3f
            while (x < w) {
                val edge = maxOf(abs(x / w - 0.5f), abs(y / h - 0.5f)) * 2f
                drawCircle(Color.Black.copy(alpha = 0.03f + 0.09f * edge * edge),
                    radius = 0.7f, center = Offset(x, y))
                x += 6f
            }
            y += 6f; row++
        }
        // Toner streaks: the classic dying-drum artefact.
        for (k in 0 until 5) {
            val sx = w * (0.14f + 0.18f * k)
            val sw = 6f + (k % 3) * 5f
            drawRect(Brush.verticalGradient(
                listOf(Color.Black.copy(alpha = 0.05f), Color.Transparent,
                       Color.Black.copy(alpha = 0.035f)), startY = 0f, endY = h),
                topLeft = Offset(sx, 0f), size = Size(sw, h))
        }
        // Tape strips, rotated by hand.
        fun tape(left: Float, top: Float) {
            rotate(-38f, pivot = Offset(left + 60f, top + 13f)) {
                drawRect(Color(0xFFD8D2BE).copy(alpha = 0.75f),
                    topLeft = Offset(left, top), size = Size(120f, 26f))
                drawRect(Color.Black.copy(alpha = 0.10f), topLeft = Offset(left, top),
                    size = Size(120f, 26f), style = Stroke(width = 1f))
            }
        }
        tape(-26f, 52f)
        tape(w - 94f, h - 96f)
    }
}

// ABYSS-only backdrop: the deep sea. Swaying light shafts from far above, marine snow
// drifting down, glowing jellyfish pulsing their way upward, an anglerfish lure bobbing
// in the lower right — and every 14s a pair of huge dim eyes opens in the dark, blinks
// once, and sinks away.
@Composable
fun AbyssBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val twoPi = 2f * Math.PI.toFloat()
        drawRect(Brush.verticalGradient(listOf(Color(0xFF041A2A), Color(0xFF020A12), Color.Black)))

        // Light shafts: soft wedges from the surface, swaying out of step with each other.
        for (k in 0 until 4) {
            val top = w * (0.12f + 0.26f * k) + sin(t * 0.21f + k * 1.9f) * w * 0.05f
            val lean = sin(t * 0.13f + k) * w * 0.10f
            val half = w * (0.04f + 0.02f * (k % 2))
            val shaft = Path().apply {
                moveTo(top - half * 0.4f, 0f); lineTo(top + half * 0.4f, 0f)
                lineTo(top + lean + half * 2.2f, h * 0.7f); lineTo(top + lean - half * 2.2f, h * 0.7f); close()
            }
            drawPath(shaft, Brush.verticalGradient(
                listOf(Color(0xFF8AFFE0).copy(alpha = 0.07f), Color.Transparent), startY = 0f, endY = h * 0.7f))
        }

        // Marine snow: slow fall with a sideways wobble.
        for (i in 0 until 60) {
            val fx = ((i * 73) % 1000) / 1000f
            val speed = 9f + ((i * 31) % 22)
            val y = (((i * 137) % 1000) / 1000f * h + t * speed) % h
            val x = fx * w + sin(t * 0.5f + i * 1.3f) * 10f
            drawCircle(Color(0xFFD4FFF2).copy(alpha = 0.16f + 0.22f * ((i % 5) / 4f)),
                radius = 1f + (i % 3) * 0.7f, center = Offset(x, y))
        }

        // The eyes, behind everything alive. Every 14s (first at ~6s): fade in over 1.5s,
        // blink once, fade out over 2s.
        // Capped at 0.35 alpha so text on top stays readable.
        val local = (t + 8f) % 14f
        if (local < 6f) {
            val a = 0.35f * when {
                local < 1.5f -> local / 1.5f
                local < 4f -> 1f
                else -> 1f - (local - 4f) / 2f
            }
            val open = if (local in 2.6f..3.0f) abs(local - 2.8f) / 0.2f else 1f
            val cycle = ((t + 8f) / 14f).toInt()
            val ew = minOf(w, h) * 0.26f
            val eh = ew * 0.5f
            val ecx = w * 0.5f + sin(cycle * 1.7f) * w * 0.06f
            val ecy = h * (0.68f + 0.04f * sin(cycle * 2.3f))
            val amber = Color(0xFFFFB020)
            for (side in listOf(-1f, 1f)) {
                val c = Offset(ecx + side * ew * 0.8f, ecy + side * ew * 0.04f)
                drawOval(brush = Brush.radialGradient(listOf(amber.copy(alpha = a * 0.35f), Color.Transparent),
                    center = c, radius = ew), topLeft = Offset(c.x - ew, c.y - ew * 0.6f), size = Size(ew * 2f, ew * 1.2f))
                if (open < 0.05f) {
                    drawLine(amber.copy(alpha = a), Offset(c.x - ew / 2f, c.y), Offset(c.x + ew / 2f, c.y), strokeWidth = 2f)
                    continue
                }
                val eye = Path().apply {
                    moveTo(c.x - ew / 2f, c.y)
                    quadraticBezierTo(c.x, c.y - eh * open, c.x + ew / 2f, c.y)
                    quadraticBezierTo(c.x, c.y + eh * open, c.x - ew / 2f, c.y); close()
                }
                drawPath(eye, Brush.radialGradient(listOf(Color(0xFFFFE08A).copy(alpha = a),
                    amber.copy(alpha = a), Color(0xFF8A4A00).copy(alpha = a)), center = c, radius = ew / 2f))
                val pupil = Path().apply {
                    moveTo(c.x, c.y - eh * 0.46f * open)
                    quadraticBezierTo(c.x + ew * 0.07f, c.y, c.x, c.y + eh * 0.46f * open)
                    quadraticBezierTo(c.x - ew * 0.07f, c.y, c.x, c.y - eh * 0.46f * open); close()
                }
                drawPath(pupil, Color(0xFF01060B).copy(alpha = (a / 0.35f) * 0.9f))
            }
        }

        // Jellyfish: a pulsing bell over wavy tentacles, rising slowly and wrapping.
        for (k in 0 until 4) {
            val tint = if (k % 2 == 0) Color(0xFFB86BFF) else Color(0xFF3DFFC8)
            val bw = (20f + 7f * k).dp.toPx() * 0.5f + 12.dp.toPx()
            val span = h + bw * 6f
            val rise = (t * (10f + 4f * k) + k * span / 4f) % span
            val cy = h + bw * 2f - rise
            val cx = w * (0.18f + 0.22f * k) + sin(t * 0.25f + k * 2.1f) * w * 0.05f
            val pulse = 0.5f + 0.5f * sin(t / 2.5f * twoPi + k * 1.7f)
            val bell = bw * (1f + 0.10f * pulse)
            val bh = bw * (0.85f - 0.12f * pulse)
            drawCircle(brush = Brush.radialGradient(listOf(tint.copy(alpha = 0.16f), Color.Transparent),
                center = Offset(cx, cy - bh * 0.4f), radius = bell * 2.4f),
                radius = bell * 2.4f, center = Offset(cx, cy - bh * 0.4f), blendMode = BlendMode.Plus)
            for (j in 0 until 5) {
                val sx = cx - bell * 0.7f + j * (bell * 1.4f / 4f)
                val len = bw * (2.0f + 0.5f * (j % 2))
                val tent = Path().apply {
                    moveTo(sx, cy)
                    for (s in 1..10) {
                        val f = s / 10f
                        lineTo(sx + sin(s * 0.8f + t * 2.2f + j + k) * bw * 0.16f * f, cy + len * f)
                    }
                }
                drawPath(tent, tint.copy(alpha = 0.30f), style = Stroke(width = 1.3f, cap = StrokeCap.Round))
            }
            val dome = Path().apply {
                moveTo(cx - bell, cy)
                cubicTo(cx - bell, cy - bh * 1.35f, cx + bell, cy - bh * 1.35f, cx + bell, cy)
                quadraticBezierTo(cx, cy - bh * 0.3f, cx - bell, cy); close()
            }
            drawPath(dome, Brush.verticalGradient(listOf(tint.copy(alpha = 0.42f), tint.copy(alpha = 0.12f)),
                startY = cy - bh, endY = cy))
            drawPath(dome, tint.copy(alpha = 0.65f), style = Stroke(width = 1.5f))
        }

        // Anglerfish lure: a glowing bead on a faint curved stalk, bobbing lower right.
        val lure = Offset(w * 0.80f + sin(t * 0.7f) * 8f, h * 0.80f + sin(t * 1.3f) * 14f)
        val stalk = Path().apply {
            moveTo(w + 12f, h * 0.90f)
            quadraticBezierTo(w * 0.86f, h * 0.70f, lure.x, lure.y)
        }
        drawPath(stalk, Color(0xFF8FC4C4).copy(alpha = 0.16f), style = Stroke(width = 2.5f, cap = StrokeCap.Round))
        val flick = 0.8f + 0.2f * sin(t * 5.3f) * sin(t * 1.7f)
        val lr = 30.dp.toPx() * flick
        drawCircle(brush = Brush.radialGradient(listOf(Color(0xFF8AFFE0).copy(alpha = 0.45f), Color.Transparent),
            center = lure, radius = lr), radius = lr, center = lure, blendMode = BlendMode.Plus)
        drawCircle(Color(0xFFE8FFF8), radius = 3.5.dp.toPx(), center = lure)

    }
}

// 11×8 space invader, two frames toggled on every march step.
private val INVADER_A = arrayOf(
    "..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.",
    "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX...")
private val INVADER_B = arrayOf(
    "..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX",
    "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X.")
private val PIXEL_SHIP = arrayOf(
    "......X......", ".....XXX.....", ".....XXX.....", ".XXXXXXXXXXX.",
    "XXXXXXXXXXXXX", "XXXXXXXXXXXXX", "XXXXXXXXXXXXX")
private val PIXEL_UFO = arrayOf(
    ".....XXXXXX.....", "...XXXXXXXXXX...", "..XXXXXXXXXXXX..", ".XX.XX.XX.XX.XX.",
    "XXXXXXXXXXXXXXXX", "..XXX..XX..XXX..", "...X........X...")

private fun DrawScope.drawSprite(rows: Array<String>, left: Float, top: Float, px: Float, color: Color) {
    rows.forEachIndexed { r, line ->
        line.forEachIndexed { c, ch ->
            if (ch == 'X') drawRect(color, Offset(left + c * px, top + r * px), Size(px, px))
        }
    }
}

// ARCADE-only backdrop: an 8-bit cabinet. Pixel stars scroll down at three speeds, a 5×3
// invader formation marches in half-second steps, a ship fires up at them, a UFO crosses
// the top now and then, all under CRT scanlines and a blinking INSERT COIN. Everything
// snaps to a pixel grid, because the hardware would have.
@Composable
fun ArcadeBackdrop(modifier: Modifier = Modifier) {
    var t by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) { val now = withFrameNanos { it }; t = (now - start) / 1_000_000_000f }
    }
    val measurer = rememberTextMeasurer()
    val coinFont = Theme.display
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val px = 2.5.dp.toPx()
        fun snap(v: Float) = (v / px).toInt() * px
        drawRect(Color.Black)

        // Stars: three parallax layers, square, snapped to the pixel grid.
        for (i in 0 until 80) {
            val layer = i % 3
            val speed = floatArrayOf(14f, 34f, 70f)[layer]
            val s = (1f + layer).dp.toPx()
            val x = ((i * 97) % 1000) / 1000f * w
            val y = (((i * 61) % 1000) / 1000f * h + t * speed) % h
            drawRect(Color.White.copy(alpha = 0.25f + 0.2f * layer), Offset(snap(x), snap(y)), Size(s, s))
        }

        // Invader formation: 5 across, 3 rows, marching in discrete steps and reversing.
        val step = (t / 0.5f).toInt()
        val sprite = if (step % 2 == 0) INVADER_A else INVADER_B
        val gap = px * 5f
        val fw = 5 * 11 * px + 4 * gap
        val margin = 16.dp.toPx()
        val stepPx = 4.dp.toPx()
        val travel = max(1, ((w - fw - 2 * margin) / stepPx).toInt())
        val k = step % (2 * travel)
        val fx = margin + (if (k <= travel) k else 2 * travel - k) * stepPx
        val fy = h * 0.13f
        val rowColors = listOf(Color(0xFF39FF14), Color(0xFFFF3CAC), Color(0xFFFFE600))
        for (r in 0 until 3) for (c in 0 until 5) {
            drawSprite(sprite, snap(fx + c * (11 * px + gap)), snap(fy + r * (8 * px + gap)), px,
                rowColors[r].copy(alpha = 0.6f))
        }

        // Ship bottom centre, firing a pixel laser upward every ~2s.
        val shipTop = h - 140.dp.toPx()
        val shipLeft = snap(w / 2f - 13 * px / 2f)
        drawSprite(PIXEL_SHIP, shipLeft, shipTop, px, Color(0xFF39FF14).copy(alpha = 0.65f))
        val shot = t % 2f
        if (shot < 0.9f) {
            val ly = shipTop - (shipTop - fy) * (shot / 0.9f)
            drawRect(Color(0xFFF0F0FF).copy(alpha = 0.8f), Offset(shipLeft + 6 * px, snap(ly)), Size(px, px * 4f))
        }

        // UFO across the top every ~20s.
        val ufo = t % 20f
        if (ufo < 7f) {
            val ux = -16 * px + (w + 32 * px) * (ufo / 7f)
            drawSprite(PIXEL_UFO, snap(ux), snap(h * 0.05f), px, Color(0xFFFF2020).copy(alpha = 0.75f))
        }

        // CRT scanlines.
        var y = 0f
        while (y < h) { drawRect(Color.Black.copy(alpha = 0.22f), Offset(0f, y), Size(w, 1f)); y += 3f }

        // INSERT COIN, blinking, small and faint.
        if (t % 1.4f < 0.8f) {
            val layout = measurer.measure("INSERT COIN",
                TextStyle(fontFamily = coinFont, fontSize = 8.sp, color = Color(0xFFFFE600)))
            drawText(layout, alpha = 0.45f, topLeft = Offset((w - layout.size.width) / 2f,
                h - 96.dp.toPx()))
        }
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
    if (Theme.themeMode == ThemeMode.NEON) {
        // Pulsing magenta edge over a cyan rim — the other electric theme.
        val shape = RoundedCornerShape(12.dp)
        val tr = rememberInfiniteTransition(label = "neon")
        val p by tr.animateFloat(
            initialValue = 0.25f, targetValue = 0.7f,
            animationSpec = infiniteRepeatable(tween(1900, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "n")
        this
            .shadow((4f + 10f * p).dp, shape, spotColor = Theme.brass, ambientColor = Theme.copper)
            .border(1.dp, Theme.copper.copy(alpha = 0.5f), shape)
            .border((1.2f + 1f * p).dp, Theme.brass.copy(alpha = 0.4f + 0.5f * p), shape)
    } else if (Theme.themeMode == ThemeMode.GARDEN) {
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
    } else if (Theme.themeMode == ThemeMode.FORGE) {
        // A steady hot edge with hard corners.
        val shape = RoundedCornerShape(1.dp)
        this
            .shadow(4.dp, shape, spotColor = Theme.brass, ambientColor = Theme.rust)
            .border(1.dp, Theme.brass.copy(alpha = 0.4f), shape)
    } else if (Theme.themeMode == ThemeMode.RANSOM) {
        // Paper: a thin ink rule, no glow at all.
        val shape = RoundedCornerShape(1.dp)
        this.border(1.dp, Theme.parchment.copy(alpha = 0.35f), shape)
    } else if (Theme.themeMode == ThemeMode.ABYSS) {
        // A slow teal breath with round 18.dp corners — alive, but calmer than electricity.
        val shape = RoundedCornerShape(18.dp)
        val tr = rememberInfiniteTransition(label = "abyss")
        val p by tr.animateFloat(
            initialValue = 0.2f, targetValue = 0.55f,
            animationSpec = infiniteRepeatable(tween(3000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "a")
        this
            .shadow(4.dp, shape, spotColor = Theme.copper, ambientColor = Theme.copper)
            .border(1.dp, Theme.brass.copy(alpha = p), shape)
    } else if (Theme.themeMode == ThemeMode.ARCADE) {
        // A steady 2.dp pixel edge, square corners, no glow.
        val shape = RoundedCornerShape(0.dp)
        this.border(2.dp, Theme.border, shape)
    } else if (Theme.themeMode == ThemeMode.WEST) {
        // No electricity: a steady sun-baked leather edge with squared 3.dp corners.
        val shape = RoundedCornerShape(3.dp)
        this
            .shadow(4.dp, shape, spotColor = Theme.brass, ambientColor = Color.Black)
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
