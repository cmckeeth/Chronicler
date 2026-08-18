package app.chronicler

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.foundation.Canvas
import androidx.compose.ui.draw.blur
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun LandingScreen(auth: AuthStore, nav: NavController) {
    val context = LocalContext.current
    // Starts optimistic so the common (online) case doesn't flash the offline panel
    // during the first reachability poll; UpdateBanner corrects it within a second.
    var connected by remember { mutableStateOf(true) }
    androidx.compose.runtime.LaunchedEffect(Unit) { StartupSound.play(context) }

    Box(Modifier.fillMaxSize()) {   // transparent: the app-wide electric backdrop shows through
        // Garden-only: real painted roses standing along the bottom at ~50% opacity, BEHIND all content.
        if (Theme.themeMode == ThemeMode.GARDEN) GardenFlowerBackdrop()

        // Steampunk-only: an old-timey industrial factory skyline pinned to the bottom,
        // BEHIND all content. Steam below rises out of its smokestacks.
        if (Theme.themeMode == ThemeMode.STEAMPUNK) FactorySkyline()

        // Corner ornaments. STEAMPUNK gets large, slowly-rotating brass cogs (below); TESLA
        // and GARDEN keep the small static glyphs in the four corners.
        if (Theme.themeMode == ThemeMode.STEAMPUNK) {
            SteampunkCogs()
        } else {
            Column(Modifier.fillMaxSize().padding(20.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    gear(); gear()
                }
                Spacer(Modifier.weight(1f))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    gear(); gear()
                }
            }
        }

        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // One action, and it follows the connection: the Archive needs the server,
            // so when it can't be reached the panel becomes the way into the downloads
            // on this device instead of a button that would fail.
            Column(
                Modifier
                    .clickable { nav.navigate(if (connected) "archive" else "offline") }
                    .electricPanel(Theme.surface, corner = 6.dp, alpha = 0.8f, elevation = 20.dp)
                    .padding(horizontal = 34.dp, vertical = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("Chronicler", color = Theme.brass, fontSize = 40.sp, fontWeight = FontWeight.Bold,
                    fontFamily = Theme.display, maxLines = 1, softWrap = false,
                    style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
                Text(if (connected) "Your Audiobook Library" else "Server unreachable",
                    color = if (connected) Theme.parchmentDim else Theme.rust, fontSize = 15.sp,
                    fontFamily = Theme.serif)
                Spacer(Modifier.height(16.dp))
                Text(if (connected) "Enter the Archive" else "📥 Listen to Downloads",
                    color = Theme.brassPale, fontSize = 18.sp,
                    fontFamily = Theme.serif,
                    style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
            }
        }

        Column(Modifier.align(Alignment.TopEnd).padding(8.dp),
            horizontalAlignment = Alignment.End) {
            TextButton(onClick = { auth.clear() }, modifier = Modifier.alpha(0.5f)) {
                Text("Sign Out", color = Theme.parchmentDim, fontSize = 11.sp)
            }
            ThemeSwitcher(auth)
        }

        UpdateBanner(auth.api, modifier = Modifier.align(Alignment.BottomCenter).padding(12.dp),
            onStatus = { connected = it })

        // Steampunk-only: lush rising steam plumes drifting over everything (non-interactive).
        if (Theme.themeMode == ThemeMode.STEAMPUNK) SteamOverlay()
    }
}

// Shared geometry for the steampunk factory: the x-fractions (of full width) of the 5
// smokestacks, and the fraction of full height where the skyline / chimney mouths sit.
// SteamOverlay anchors its plumes to these so steam puffs out of the stacks.
private val STACK_XS = floatArrayOf(0.09f, 0.30f, 0.50f, 0.69f, 0.90f)
private const val SKYLINE_TOP_FRAC = 0.74f   // chimney mouths live just above the skyline base

// STEAMPUNK only: an old-timey industrial factory SILHOUETTE pinned to the bottom of the
// screen — low buildings + 5 tall flared smokestacks + a big cogwheel — with a soft warm
// glow on top. Dark fill with a thin warm rim. Non-interactive (drawn behind content).
@Composable
private fun FactorySkyline() {
    val fill = Color(0xFF0C0702)
    val rim = Color(0xFF5A3414)
    val glow = Color(0xFFB8731F)

    Box(Modifier.fillMaxSize()) {
        Canvas(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(210.dp)
        ) {
            val w = size.width; val h = size.height
            // Soft warm glow hugging the top of the skyline.
            drawRect(
                brush = Brush.verticalGradient(
                    colors = listOf(glow.copy(alpha = 0f), glow.copy(alpha = 0.14f)),
                    startY = 0f, endY = h * 0.55f),
                size = size)

            val rimStroke = Stroke(width = 2f)

            // Low factory buildings across the base — varied heights, flat roofs.
            data class B(val xf: Float, val wf: Float, val topf: Float)
            val buildings = listOf(
                B(-0.02f, 0.18f, 0.55f), B(0.15f, 0.16f, 0.42f), B(0.30f, 0.20f, 0.60f),
                B(0.49f, 0.15f, 0.38f), B(0.62f, 0.19f, 0.56f), B(0.80f, 0.22f, 0.46f))
            for (b in buildings) {
                val left = w * b.xf
                val bw = w * b.wf
                val top = h * b.topf
                val rect = Path().apply {
                    moveTo(left, h); lineTo(left, top)
                    lineTo(left + bw, top); lineTo(left + bw, h); close()
                }
                drawPath(rect, color = fill)
                drawPath(rect, color = rim, style = rimStroke)
            }

            // Five tall smokestacks: a slightly tapered chimney with a flared cap, each
            // sitting at the shared STACK_XS so steam aligns with the mouths.
            val stackHeights = floatArrayOf(0.20f, 0.06f, 0.10f, 0.04f, 0.16f) // top-frac of full height
            val stackW = w * 0.045f
            for (i in STACK_XS.indices) {
                val cx = w * STACK_XS[i]
                // mouth y (in this Canvas's coords): SKYLINE_TOP_FRAC of full screen maps here as 0,
                // and the stack rises above that. We draw within the 210dp band, so use stackHeights.
                val topY = h * stackHeights[i]
                val halfTop = stackW * 0.42f
                val halfBot = stackW * 0.55f
                // Chimney body (tapered: narrower at top).
                val body = Path().apply {
                    moveTo(cx - halfBot, h); lineTo(cx - halfTop, topY)
                    lineTo(cx + halfTop, topY); lineTo(cx + halfBot, h); close()
                }
                drawPath(body, color = fill)
                drawPath(body, color = rim, style = rimStroke)
                // Flared cap at the mouth.
                val capH = h * 0.022f
                val capHalf = halfTop * 1.7f
                val cap = Path().apply {
                    moveTo(cx - halfTop, topY); lineTo(cx - capHalf, topY - capH)
                    lineTo(cx + capHalf, topY - capH); lineTo(cx + halfTop, topY); close()
                }
                drawPath(cap, color = fill)
                drawPath(cap, color = rim, style = rimStroke)
            }

            // A big cogwheel embedded in the skyline (right-of-centre, half-sunk).
            val cogC = Offset(w * 0.50f, h * 0.92f)
            val cogR = h * 0.30f
            drawCircle(color = fill, radius = cogR, center = cogC)
            drawCircle(color = rim, radius = cogR, center = cogC, style = Stroke(width = 2.5f))
            // Hub.
            drawCircle(color = rim, radius = cogR * 0.30f, center = cogC, style = Stroke(width = 2f))
            // Teeth around the rim.
            val teeth = 14
            for (k in 0 until teeth) {
                val ang = (k.toFloat() / teeth) * 6.2831853f
                val r0 = cogR
                val r1 = cogR + h * 0.035f
                drawLine(
                    color = rim,
                    start = Offset(cogC.x + cos(ang) * r0, cogC.y + sin(ang) * r0),
                    end = Offset(cogC.x + cos(ang) * r1, cogC.y + sin(ang) * r1),
                    strokeWidth = 4f)
            }
        }
    }
}

// STEAMPUNK only: 9 soft steam plumes that EMIT FROM the factory smokestacks. Each plume
// starts near a chimney mouth (just above the skyline) at one of the 5 stack x-fractions —
// some stacks emit two — then billows up the screen, growing and fading. Several looping
// timelines with different durations/phases keep them from pulsing in unison. Each plume is
// a blurred cream radial-gradient blob. Non-interactive (rising over content is fine).
@Composable
private fun SteamOverlay() {
    val transition = rememberInfiniteTransition(label = "steam")
    // A few independent looping timelines so plumes don't all rise in lockstep.
    val p1 by transition.animateFloat(0f, 1f,
        infiniteRepeatable(tween(7000, easing = LinearEasing), RepeatMode.Restart), label = "s1")
    val p2 by transition.animateFloat(0f, 1f,
        infiniteRepeatable(tween(9000, easing = LinearEasing), RepeatMode.Restart), label = "s2")
    val p3 by transition.animateFloat(0f, 1f,
        infiniteRepeatable(tween(11000, easing = LinearEasing), RepeatMode.Restart), label = "s3")
    val timelines = listOf(p1, p2, p3)

    // Each plume's source x-fraction: the 5 stacks, plus the two biggest stacks (0 and 4)
    // emit a second plume → 7 here; the per-plume phase fill keeps the column busy.
    val sources = floatArrayOf(
        STACK_XS[0], STACK_XS[1], STACK_XS[2], STACK_XS[3], STACK_XS[4],
        STACK_XS[0], STACK_XS[4], STACK_XS[2], STACK_XS[1])
    val plumes = sources.size   // 9
    val cream = Color(0xFFFFF6E6)

    Canvas(Modifier.fillMaxSize().blur(24.dp)) {
        val w = size.width; val h = size.height
        // Steam is born at the chimney mouths (just above the skyline) and rises to the top.
        val mouthY = h * SKYLINE_TOP_FRAC
        for (i in 0 until plumes) {
            // Stagger each plume's phase so each stack always has steam.
            val phase = i / plumes.toFloat()
            val raw = timelines[i % timelines.size] + phase
            val prog = raw - kotlin.math.floor(raw)   // 0..1 looping

            // Anchor to a chimney mouth; small horizontal sway as the steam rises.
            val baseX = w * sources[i]
            val sway = sin((prog + phase) * 6.2831853f) * w * 0.04f
            val x = baseX + sway

            // Rise from the chimney mouth up past the top of the screen.
            val y = mouthY - (mouthY + h * 0.20f) * prog

            // Grow as it rises (start small at the mouth).
            val radius = w * (0.05f + 0.24f * prog)

            // Fade in quickly at the mouth, then fade out toward the top (peak ~0.55).
            val fadeIn = (prog / 0.12f).coerceAtMost(1f)
            val fadeOut = ((1f - prog) / 0.55f).coerceAtMost(1f)
            val alpha = 0.55f * fadeIn * fadeOut
            if (alpha <= 0.01f) continue

            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(cream.copy(alpha = alpha), cream.copy(alpha = 0f)),
                    center = Offset(x, y), radius = radius),
                radius = radius, center = Offset(x, y))
        }
    }
}

// STEAMPUNK only: four large brass cogs pinned to the corners, each rotating slowly and
// continuously (alternating CW/CCW, ~15-36s per turn) at low alpha so they read as
// background ornament. Mirrors the web app's rotating-cog corners. Non-interactive.
@Composable
private fun SteampunkCogs() {
    val t = rememberInfiniteTransition(label = "cogs")
    @Composable
    fun spin(periodMs: Int, cw: Boolean): Float {
        val deg by t.animateFloat(
            initialValue = 0f,
            targetValue = if (cw) 360f else -360f,
            animationSpec = infiniteRepeatable(tween(periodMs, easing = LinearEasing), RepeatMode.Restart),
            label = "spin$periodMs",
        )
        return deg
    }
    val r1 = spin(36000, cw = true)
    val r2 = spin(22000, cw = false)
    val r3 = spin(28000, cw = false)
    val r4 = spin(15000, cw = true)
    Box(Modifier.fillMaxSize()) {
        Cog(Alignment.TopStart,     sizeDp = 150, xDp = -46, yDp = -34, deg = r1, alpha = 0.20f)
        Cog(Alignment.TopEnd,       sizeDp = 120, xDp = 40,  yDp = -28, deg = r2, alpha = 0.18f)
        Cog(Alignment.BottomStart,  sizeDp = 128, xDp = -40, yDp = 36,  deg = r3, alpha = 0.18f)
        Cog(Alignment.BottomEnd,    sizeDp = 150, xDp = 46,  yDp = 40,  deg = r4, alpha = 0.22f)
    }
}

@Composable
private fun BoxScope.Cog(
    align: Alignment, sizeDp: Int, xDp: Int, yDp: Int, deg: Float, alpha: Float,
) {
    Text(
        "⚙", color = Theme.borderBrass, fontSize = (sizeDp * 0.9f).sp, softWrap = false,
        modifier = Modifier
            .align(align)
            .offset(x = xDp.dp, y = yDp.dp)
            .alpha(alpha)
            .rotate(deg),
    )
}

@Composable
private fun gear() {
    // Garden trades the steampunk gear for a leaf; Tesla/Steampunk keep the gear.
    val glyph = if (Theme.themeMode == ThemeMode.GARDEN) "🌿" else "⚙"
    Text(glyph, color = Theme.border, fontSize = 26.sp, modifier = Modifier.alpha(0.6f))
}

private fun ThemeMode.label(): String = when (this) {
    ThemeMode.TESLA -> "⚡ Tesla"
    ThemeMode.STEAMPUNK -> "⚙ Steampunk"
    ThemeMode.GARDEN -> "🌿 Garden"
    ThemeMode.ACADEMIA -> "📖 Dark Academia"
    ThemeMode.NOIR -> "🦇 Blackletter Noir"
    ThemeMode.WEST -> "🤠 Wild West"
}

// Theme selector as a compact DROPDOWN: a themed outlined field shows the current theme;
// tapping it opens a Material3 DropdownMenu listing all three. Selecting one sets
// Theme.themeMode (recomposes the app) and persists it via AuthStore.
@Composable
private fun ThemeSwitcher(auth: AuthStore) {
    val active = Theme.themeMode
    val context = LocalContext.current
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(Theme.surface)
                .border(1.dp, Theme.borderBrass.copy(alpha = 0.6f), RoundedCornerShape(6.dp))
                .clickable { expanded = true }
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(active.label(), color = Theme.brassPale, fontSize = 11.sp,
                fontWeight = FontWeight.Bold, fontFamily = Theme.serif)
            Text("▾", color = Theme.parchmentDim, fontSize = 11.sp)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.background(Theme.surface)
        ) {
            ThemeMode.entries.forEach { mode ->
                DropdownMenuItem(
                    text = {
                        Text(mode.label(),
                            color = if (mode == active) Theme.brass else Theme.parchmentDim,
                            fontSize = 12.sp,
                            fontWeight = if (mode == active) FontWeight.Bold else FontWeight.Normal,
                            fontFamily = Theme.serif)
                    },
                    onClick = { auth.setThemeMode(mode); StartupSound.playTheme(context); expanded = false }
                )
            }
        }
    }
}

// Status bar + self-update prompt, ported from the Blazor UpdateBanner.
// Shared by the landing and archive pages.
@Composable
fun UpdateBanner(api: ApiClient, modifier: Modifier = Modifier,
                 // Lets the hosting screen react to the connection state (e.g. surface
                 // Local Downloads).
                 onStatus: (Boolean) -> Unit = {},
                 // Archive uses the compact form so the status line costs as little
                 // height as possible — the covers want that space.
                 compact: Boolean = false) {
    val context = LocalContext.current
    val current = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: "?"
    }
    var connected by remember { mutableStateOf(false) }
    var latest by remember { mutableStateOf<String?>(null) }
    val latestVer = latest
    val updateAvailable = latestVer != null && latestVer != "0.0.0" && isNewer(latestVer, current)

    LaunchedEffect(Unit) {
        while (true) {
            val v = api.getLatestVersion()
            connected = v != null
            onStatus(connected)
            if (v != null) latest = v
            kotlinx.coroutines.delay(10_000)
        }
    }

    val small = if (compact) 10.sp else 12.sp
    Row(modifier, verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 5.dp else 8.dp)) {
        Text("●", color = if (connected) Theme.verdigris else Theme.rust,
            fontSize = if (compact) 7.sp else 10.sp)
        Text("v$current", color = Theme.parchmentDim, fontSize = small)
        if (updateAvailable) {
            Text("⚡ v$latestVer available — tap to install",
                color = Theme.brassPale, fontSize = small, fontWeight = FontWeight.Bold,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
                modifier = Modifier.clickable {
                    val url = "${ApiClient.BASE_URL}/api/update/apk/Chronicler-v$latestVer.apk"
                    context.startActivity(
                        android.content.Intent(android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(url)))
                })
        } else {
            Text(if (connected) "Connected" else "Server unreachable",
                color = Theme.parchmentDim, fontSize = small)
        }
    }
}

// Compare dotted versions: is [a] strictly newer than [b]?
private fun isNewer(a: String, b: String): Boolean {
    val pa = a.split(".").map { it.toIntOrNull() ?: 0 }
    val pb = b.split(".").map { it.toIntOrNull() ?: 0 }
    for (i in 0 until maxOf(pa.size, pb.size)) {
        val x = pa.getOrElse(i) { 0 }; val y = pb.getOrElse(i) { 0 }
        if (x != y) return x > y
    }
    return false
}
