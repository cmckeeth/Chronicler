package app.chronicler

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Three runtime themes:
//   TESLA     — electric-blue look (the current default; animated lightning everywhere).
//   STEAMPUNK — Victorian brass/gold, NO electricity (static brass borders, green accent).
//   GARDEN    — verdant greens + floral pink accents, NO electricity (soft solid panels,
//               rounded organic corners, steady soft-green glow, handwritten/rounded fonts).
enum class ThemeMode { TESLA, STEAMPUNK, GARDEN }

// Theme palette. Every themed color is a computed `get()` that reads [themeMode], so any
// composable that touches a color recomposes when the mode flips (mutableStateOf is observed
// inside composition). Call sites are unchanged — `Theme.bg` still reads like a constant.
object Theme {
    // Backing state. Flip this to switch themes app-wide; MainActivity restores it on launch.
    var themeMode by mutableStateOf(ThemeMode.TESLA)

    private val tesla get() = themeMode == ThemeMode.TESLA
    private val garden get() = themeMode == ThemeMode.GARDEN

    // Pick a per-theme value. Order: TESLA, STEAMPUNK, GARDEN.
    private fun <T> byTheme(tesla: T, steampunk: T, garden: T): T = when (themeMode) {
        ThemeMode.TESLA -> tesla
        ThemeMode.STEAMPUNK -> steampunk
        ThemeMode.GARDEN -> garden
    }

    // TESLA — cold futuristic glass/electric (dark blue-black, electric-blue "metal").
    // STEAMPUNK — warm Victorian brass/gold/leather, green accent (unchanged).
    // GARDEN — verdant greens, foliage-green "metal", floral-pink accent.
    val bg: Color get() = byTheme(Color(0xFF05080F), Color(0xFF160D03), Color(0xFF0B1410))
    val bg2: Color get() = byTheme(Color(0xFF090E1A), Color(0xFF1E1206), Color(0xFF0F1C14))
    val leather: Color get() = byTheme(Color(0xFF0B1424), Color(0xFF281809), Color(0xFF12241A))
    val surface: Color get() = byTheme(Color(0xFF0F1A2E), Color(0xFF32200C), Color(0xFF16301F))
    val surface2: Color get() = byTheme(Color(0xFF142440), Color(0xFF3E280E), Color(0xFF1D3D28))
    val surface3: Color get() = byTheme(Color(0xFF1B3052), Color(0xFF4A3012), Color(0xFF245031))
    val border: Color get() = byTheme(Color(0xFF21405F), Color(0xFF6B4420), Color(0xFF2F5C3C))
    val borderBrass: Color get() = byTheme(Color(0xFF3F86B8), Color(0xFFC08828), Color(0xFF6FAE5F))
    // "brass"/metal token (~used everywhere for buttons, wordmark). TESLA = electric blue/chrome,
    // GARDEN = foliage green.
    val brass: Color get() = byTheme(Color(0xFF2BC4FF), Color(0xFFE09808), Color(0xFF8BD450))
    val brassLight: Color get() = byTheme(Color(0xFF7FE0FF), Color(0xFFFFC838), Color(0xFFB6F07A))
    val brassPale: Color get() = byTheme(Color(0xFFD6F4FF), Color(0xFFFFE878), Color(0xFFE2FFC0))
    val copper: Color get() = byTheme(Color(0xFF1F9FD8), Color(0xFFC86818), Color(0xFFE88FA8))
    val rust: Color get() = byTheme(Color(0xFFFF5470), Color(0xFFB82C0C), Color(0xFFD4564A))
    // Accent / "electric" token. Name kept (used ~35 places). TESLA = electric blue,
    // STEAMPUNK = verdigris green, GARDEN = floral pink — the key accent flip.
    val verdigris: Color get() = byTheme(Color(0xFF2BC4FF), Color(0xFF8FD44A), Color(0xFFFF8FB8))
    val parchment: Color get() = byTheme(Color(0xFFE6F3FF), Color(0xFFF6ECD0), Color(0xFFF0F7E8))
    val parchmentMid: Color get() = byTheme(Color(0xFFA6C8E2), Color(0xFFE0BC6C), Color(0xFFCFE4B8))
    val parchmentDim: Color get() = byTheme(Color(0xFF6F93B4), Color(0xFFC09838), Color(0xFF9BBF88))
    val ink: Color get() = byTheme(Color(0xFF04101E), Color(0xFF1A0C02), Color(0xFF08130C))

    // Soft green halo color used for GARDEN headings/panels (no electricity, no pulse).
    private val gardenGlow get() = Color(0xFF7CC24A)

    val brassGradient: Brush get() = Brush.verticalGradient(listOf(brassLight, brass, borderBrass))

    // Per-theme fonts. STEAMPUNK = ornate serif (Cinzel/Lora). TESLA = clean geometric
    // sans (Orbitron display + Rajdhani body) for a cold, futuristic feel. Orbitron ships
    // as a variable font — map weights via FontVariation (minSdk 26 supports it).
    private val cinzelDisplay = FontFamily(
        Font(R.font.cinzel_decorative_regular, FontWeight.Normal),
        Font(R.font.cinzel_decorative_bold, FontWeight.Bold),
        Font(R.font.cinzel_decorative_black, FontWeight.Black),
    )
    @OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
    private val orbitronDisplay = FontFamily(
        Font(R.font.orbitron, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
        Font(R.font.orbitron, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
        Font(R.font.orbitron, FontWeight.Black, variationSettings = FontVariation.Settings(FontVariation.weight(900))),
    )
    private val cinzelSerif = FontFamily(Font(R.font.cinzel))
    private val rajdhaniSerif = FontFamily(
        Font(R.font.rajdhani_semibold, FontWeight.Normal),
        Font(R.font.rajdhani_semibold, FontWeight.Bold),
    )
    private val loraBody = FontFamily(Font(R.font.lora))
    private val rajdhaniBody = FontFamily(
        Font(R.font.rajdhani_regular, FontWeight.Normal),
        Font(R.font.rajdhani_medium, FontWeight.Medium),
        Font(R.font.rajdhani_semibold, FontWeight.Bold),
    )

    // GARDEN — signature script (Dancing Script) for display, Quicksand (rounded) for
    // body/serif. Both ship as variable fonts (like Orbitron); map weights via FontVariation.
    @OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
    private val dancingDisplay = FontFamily(
        Font(R.font.dancing_script, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
        Font(R.font.dancing_script, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
        Font(R.font.dancing_script, FontWeight.Black, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    )
    @OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
    private val quicksandBody = FontFamily(
        Font(R.font.quicksand, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
        Font(R.font.quicksand, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
        Font(R.font.quicksand, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    )
    @OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
    private val quicksandSerif = FontFamily(
        Font(R.font.quicksand, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
        Font(R.font.quicksand, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    )

    val display: FontFamily get() = byTheme(orbitronDisplay, cinzelDisplay, dancingDisplay)
    val serif: FontFamily get() = byTheme(rajdhaniSerif, cinzelSerif, quicksandSerif)
    val body: FontFamily get() = byTheme(rajdhaniBody, loraBody, quicksandBody)

    // Glows read the themed colors via get() so they re-evaluate when the mode flips.
    // STEAMPUNK headings get a warm brass halo; TESLA gets the bright electric-blue one;
    // GARDEN gets a steady soft-green halo (no electricity, no pulse).
    val glowBrass: Shadow get() = Shadow(color = brass.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 24f)
    val glowVerdigris: Shadow
        get() = byTheme(
            Shadow(color = verdigris.copy(alpha = 1f), offset = Offset.Zero, blurRadius = 36f),
            Shadow(color = brass.copy(alpha = 0.7f), offset = Offset.Zero, blurRadius = 18f),
            Shadow(color = gardenGlow.copy(alpha = 0.75f), offset = Offset.Zero, blurRadius = 22f),
        )
}

// Themed panel.
//   TESLA     — a GLASSY panel: translucent low-alpha surface fill + faint top-down gradient
//               sheen + thin bright cyan border + soft rounded corners, plus a BREATHING
//               electric-blue edge (stroke alpha/width + glow elevation pulse forever).
//               (Compose has no cheap backdrop blur, so glass is faked with translucency.)
//   STEAMPUNK — a SOLID opaque brass panel with tight 2.dp corners + static brass border
//               and a steady drop shadow (no pulse, no electricity, no glass).
// Built with composed {} so it can hold the infinite transition (TESLA) while keeping a plain
// Modifier signature (no call-site changes).
fun Modifier.electricPanel(
    bg: Color = Theme.surface,
    corner: Dp = 4.dp,
    alpha: Float = 0.6f,
    elevation: Dp = 14.dp,
): Modifier = composed {
    if (Theme.themeMode == ThemeMode.GARDEN) {
        // Frosted-translucent green panel: generous 16.dp radius, gentle green border + soft
        // bloom. Lowered fill alpha so the vector-flower wallpaper reads through (real backdrop
        // blur is unavailable in Compose — translucency stands in). No animation, no glass.
        val shape = RoundedCornerShape(16.dp)
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .background(bg.copy(alpha = 0.72f), shape)
            .border(1.4.dp, Theme.borderBrass.copy(alpha = (alpha * 0.7f).coerceAtMost(1f)), shape)
    } else if (Theme.themeMode == ThemeMode.STEAMPUNK) {
        // Solid opaque brass panel, tight 2.dp corners — no animation, no glass.
        val shape = RoundedCornerShape(2.dp)
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .background(bg, shape)
            .border(1.6.dp, Theme.borderBrass.copy(alpha = (alpha + 0.2f).coerceAtMost(1f)), shape)
    } else {
        // Glassy Tesla panel: soft 10.dp corners, translucent fill + sheen, breathing cyan edge.
        val shape = RoundedCornerShape(10.dp)
        val t = rememberInfiniteTransition(label = "panel")
        val p by t.animateFloat(
            initialValue = 0f, targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(1700, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "pulse")
        val glass = Brush.verticalGradient(
            listOf(
                Color.White.copy(alpha = 0.06f),
                bg.copy(alpha = 0.34f),
                bg.copy(alpha = 0.50f),
            )
        )
        this
            .shadow(elevation * (1.3f + 1.0f * p), shape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
            .background(bg.copy(alpha = 0.30f), shape)
            .background(glass, shape)
            .border((1.4f + 0.8f * p).dp, Theme.verdigris.copy(alpha = (0.55f + 0.45f * p).coerceAtMost(1f)), shape)
    }
}

fun formatTime(seconds: Double): String {
    if (!seconds.isFinite() || seconds < 0) return "0:00"
    val total = seconds.toInt()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
