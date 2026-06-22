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

// Two runtime themes:
//   TESLA     — electric-blue look (the current default; animated lightning everywhere).
//   STEAMPUNK — Victorian brass/gold, NO electricity (static brass borders, green accent).
enum class ThemeMode { TESLA, STEAMPUNK }

// Theme palette. Every themed color is a computed `get()` that reads [themeMode], so any
// composable that touches a color recomposes when the mode flips (mutableStateOf is observed
// inside composition). Call sites are unchanged — `Theme.bg` still reads like a constant.
object Theme {
    // Backing state. Flip this to switch themes app-wide; MainActivity restores it on launch.
    var themeMode by mutableStateOf(ThemeMode.TESLA)

    private val tesla get() = themeMode == ThemeMode.TESLA

    // TESLA — cold futuristic glass/electric (dark blue-black, electric-blue "metal").
    // STEAMPUNK — warm Victorian brass/gold/leather, green accent (unchanged).
    val bg: Color get() = if (tesla) Color(0xFF05080F) else Color(0xFF160D03)
    val bg2: Color get() = if (tesla) Color(0xFF090E1A) else Color(0xFF1E1206)
    val leather: Color get() = if (tesla) Color(0xFF0B1424) else Color(0xFF281809)
    val surface: Color get() = if (tesla) Color(0xFF0F1A2E) else Color(0xFF32200C)
    val surface2: Color get() = if (tesla) Color(0xFF142440) else Color(0xFF3E280E)
    val surface3: Color get() = if (tesla) Color(0xFF1B3052) else Color(0xFF4A3012)
    val border: Color get() = if (tesla) Color(0xFF21405F) else Color(0xFF6B4420)
    val borderBrass: Color get() = if (tesla) Color(0xFF3F86B8) else Color(0xFFC08828)
    // "brass"/metal token (~used everywhere for buttons, wordmark). TESLA = electric blue/chrome.
    val brass: Color get() = if (tesla) Color(0xFF2BC4FF) else Color(0xFFE09808)
    val brassLight: Color get() = if (tesla) Color(0xFF7FE0FF) else Color(0xFFFFC838)
    val brassPale: Color get() = if (tesla) Color(0xFFD6F4FF) else Color(0xFFFFE878)
    val copper: Color get() = if (tesla) Color(0xFF1F9FD8) else Color(0xFFC86818)
    val rust: Color get() = if (tesla) Color(0xFFFF5470) else Color(0xFFB82C0C)
    // Accent / "electric" token. Name kept (used ~35 places). TESLA = electric blue,
    // STEAMPUNK = verdigris green — the key accent flip.
    val verdigris: Color get() = if (tesla) Color(0xFF2BC4FF) else Color(0xFF8FD44A)
    val parchment: Color get() = if (tesla) Color(0xFFE6F3FF) else Color(0xFFF6ECD0)
    val parchmentMid: Color get() = if (tesla) Color(0xFFA6C8E2) else Color(0xFFE0BC6C)
    val parchmentDim: Color get() = if (tesla) Color(0xFF6F93B4) else Color(0xFFC09838)
    val ink: Color get() = if (tesla) Color(0xFF04101E) else Color(0xFF1A0C02)

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

    val display: FontFamily get() = if (tesla) orbitronDisplay else cinzelDisplay
    val serif: FontFamily get() = if (tesla) rajdhaniSerif else cinzelSerif
    val body: FontFamily get() = if (tesla) rajdhaniBody else loraBody

    // Glows read the themed colors via get() so they re-evaluate when the mode flips.
    // STEAMPUNK headings get a warm brass halo; TESLA gets the bright electric-blue one.
    val glowBrass: Shadow get() = Shadow(color = brass.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 24f)
    val glowVerdigris: Shadow
        get() = if (tesla)
            Shadow(color = verdigris.copy(alpha = 1f), offset = Offset.Zero, blurRadius = 36f)
        else
            Shadow(color = brass.copy(alpha = 0.7f), offset = Offset.Zero, blurRadius = 18f)
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
    if (Theme.themeMode == ThemeMode.STEAMPUNK) {
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
