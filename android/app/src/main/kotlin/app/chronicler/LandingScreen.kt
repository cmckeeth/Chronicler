package app.chronicler

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.delay
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke

@Composable
fun LandingScreen(auth: AuthStore, nav: NavController) {
    val context = LocalContext.current
    androidx.compose.runtime.LaunchedEffect(Unit) { StartupSound.play(context) }

    Box(Modifier.fillMaxSize()) {   // transparent: the app-wide electric backdrop shows through
        // Garden-only: a soft vector-flower wallpaper at ~50% opacity, BEHIND all content.
        if (Theme.themeMode == ThemeMode.GARDEN) GardenFlowerBackdrop()

        // Gear corners
        Column(Modifier.fillMaxSize().padding(20.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                gear(); gear()
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                gear(); gear()
            }
        }

        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Chronicler", color = Theme.brass, fontSize = 38.sp, fontWeight = FontWeight.Bold,
                fontFamily = Theme.display, maxLines = 1, softWrap = false,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
            Text("Your Audiobook Library", color = Theme.parchmentDim, fontSize = 15.sp,
                fontFamily = Theme.serif)
            Spacer(Modifier.height(8.dp))
            Text(if (Theme.themeMode == ThemeMode.GARDEN) "🌿 ───────── 🌿" else "⚙ ───────── ⚙",
                color = Theme.borderBrass, fontSize = 14.sp)
            Spacer(Modifier.height(40.dp))

            Column(
                Modifier
                    .clickable { nav.navigate("archive") }
                    .electricPanel(Theme.surface, corner = 6.dp, alpha = 0.8f, elevation = 20.dp)
                    .padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Image(painterResource(R.drawable.logo), contentDescription = null,
                    modifier = Modifier.size(190.dp))
                Text("Enter the Archive", color = Theme.brassPale, fontSize = 20.sp,
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

        UpdateBanner(auth.api, modifier = Modifier.align(Alignment.BottomCenter).padding(12.dp))

        // Garden-only: vines grow up, then a flower blooms slowly at each tip.
        if (Theme.themeMode == ThemeMode.GARDEN) VineGrowOverlay()
    }
}

// GARDEN only: vines grow up from the bottom (the stem "draws" itself via PathMeasure),
// then a hand-built VECTOR flower blooms slowly at the tip (no emoji).
@Composable
private fun VineGrowOverlay() {
    Box(Modifier.fillMaxSize()) {
        Vine(Alignment.BottomStart,  xDp = 6,   heightDp = 250, hue = FlowerHue.ROSE,  growMs = 3200)
        Vine(Alignment.BottomEnd,    xDp = -6,  heightDp = 250, hue = FlowerHue.WHITE, growMs = 3700)
        Vine(Alignment.BottomCenter, xDp = 0,   heightDp = 185, hue = FlowerHue.GOLD,  growMs = 3000)
    }
}

@Composable
private fun BoxScope.Vine(align: Alignment, xDp: Int, heightDp: Int, hue: FlowerHue, growMs: Int) {
    var started by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { started = true }
    val grow by animateFloatAsState(
        targetValue = if (started) 1f else 0f,
        animationSpec = tween(durationMillis = growMs, easing = FastOutSlowInEasing),
        label = "vineGrow")
    var bloom by remember { mutableStateOf(false) }
    LaunchedEffect(started) { if (started) { delay(growMs.toLong()); bloom = true } }
    val flowerScale by animateFloatAsState(
        targetValue = if (bloom) 1f else 0f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessVeryLow),
        label = "vineFlower")

    val stem = Color(0xFF6FAE5F)
    Box(Modifier.align(align).offset(x = xDp.dp).width(130.dp).height(heightDp.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            val w = size.width; val h = size.height
            val path = Path().apply {
                moveTo(w * 0.5f, h)
                cubicTo(w * 0.16f, h * 0.80f, w * 0.88f, h * 0.62f, w * 0.42f, h * 0.46f)
                cubicTo(w * 0.08f, h * 0.30f, w * 0.82f, h * 0.18f, w * 0.52f, h * 0.05f)
            }
            val pm = PathMeasure().apply { setPath(path, false) }
            val seg = Path()
            pm.getSegment(0f, grow * pm.length, seg, true)
            drawPath(seg, color = stem, style = Stroke(width = 8f, cap = StrokeCap.Round))
        }
        // Hand-built VECTOR flower at the tip — blooms after the stem finishes (no emoji).
        Canvas(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = (-10).dp)
                .size(72.dp)
                .scale(flowerScale)
        ) { drawFlower(hue) }
    }
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
}

// Theme selector as a compact DROPDOWN: a themed outlined field shows the current theme;
// tapping it opens a Material3 DropdownMenu listing all three. Selecting one sets
// Theme.themeMode (recomposes the app) and persists it via AuthStore.
@Composable
private fun ThemeSwitcher(auth: AuthStore) {
    val active = Theme.themeMode
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
                    onClick = { auth.setThemeMode(mode); expanded = false }
                )
            }
        }
    }
}

// Status bar + self-update prompt, ported from the Blazor UpdateBanner.
// Shared by the landing and archive pages.
@Composable
fun UpdateBanner(api: ApiClient, modifier: Modifier = Modifier) {
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
            if (v != null) latest = v
            kotlinx.coroutines.delay(10_000)
        }
    }

    Row(modifier, verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("●", color = if (connected) Theme.verdigris else Theme.rust, fontSize = 10.sp)
        Text("v$current", color = Theme.parchmentDim, fontSize = 12.sp)
        if (updateAvailable) {
            Text("⚡ v$latestVer available — tap to install",
                color = Theme.brassPale, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
                modifier = Modifier.clickable {
                    val url = "${ApiClient.BASE_URL}/api/update/apk/Chronicler-v$latestVer.apk"
                    context.startActivity(
                        android.content.Intent(android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(url)))
                })
        } else {
            Text(if (connected) "Connected" else "Server unreachable",
                color = Theme.parchmentDim, fontSize = 12.sp)
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
