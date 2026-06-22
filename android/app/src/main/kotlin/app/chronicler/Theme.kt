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

    val bg: Color get() = if (tesla) Color(0xFF120A02) else Color(0xFF160D03)
    val bg2: Color get() = if (tesla) Color(0xFF1A1005) else Color(0xFF1E1206)
    val leather: Color get() = if (tesla) Color(0xFF221408) else Color(0xFF281809)
    val surface: Color get() = if (tesla) Color(0xFF2A1A0A) else Color(0xFF32200C)
    val surface2: Color get() = if (tesla) Color(0xFF341F0C) else Color(0xFF3E280E)
    val surface3: Color get() = if (tesla) Color(0xFF3E260E) else Color(0xFF4A3012)
    val border: Color get() = if (tesla) Color(0xFF5A3418) else Color(0xFF6B4420)
    val borderBrass: Color get() = if (tesla) Color(0xFFB87C20) else Color(0xFFC08828)
    val brass: Color get() = if (tesla) Color(0xFFE8A010) else Color(0xFFE09808)
    val brassLight: Color get() = if (tesla) Color(0xFFFFC030) else Color(0xFFFFC838)
    val brassPale: Color get() = if (tesla) Color(0xFFFFE060) else Color(0xFFFFE878)
    val copper: Color get() = if (tesla) Color(0xFFD07020) else Color(0xFFC86818)
    val rust: Color get() = if (tesla) Color(0xFFC03010) else Color(0xFFB82C0C)
    // Accent / "electric" token. Name kept (used ~35 places). TESLA = electric blue,
    // STEAMPUNK = verdigris green — the key accent flip.
    val verdigris: Color get() = if (tesla) Color(0xFF2BC4FF) else Color(0xFF8FD44A)
    val parchment: Color get() = if (tesla) Color(0xFFFFF4D8) else Color(0xFFF6ECD0)
    val parchmentMid: Color get() = if (tesla) Color(0xFFE8C878) else Color(0xFFE0BC6C)
    val parchmentDim: Color get() = if (tesla) Color(0xFFC8A048) else Color(0xFFC09838)
    val ink: Color get() = if (tesla) Color(0xFF1A0C02) else Color(0xFF1A0C02)

    val brassGradient: Brush get() = Brush.verticalGradient(listOf(brassLight, brass, borderBrass))

    // Fonts (shared by both themes; not re-bundled per theme — known gap vs. CSS Cinzel/Lora).
    val display = FontFamily(
        Font(R.font.cinzel_decorative_regular, FontWeight.Normal),
        Font(R.font.cinzel_decorative_bold, FontWeight.Bold),
        Font(R.font.cinzel_decorative_black, FontWeight.Black),
    )
    val serif = FontFamily(Font(R.font.cinzel))
    val body = FontFamily(Font(R.font.lora))

    // Glows read the themed colors via get() so they re-evaluate when the mode flips.
    // STEAMPUNK headings get a warm brass halo; TESLA gets the bright electric-blue one.
    val glowBrass: Shadow get() = Shadow(color = brass.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 24f)
    val glowVerdigris: Shadow
        get() = if (tesla)
            Shadow(color = verdigris.copy(alpha = 1f), offset = Offset.Zero, blurRadius = 36f)
        else
            Shadow(color = brass.copy(alpha = 0.7f), offset = Offset.Zero, blurRadius = 18f)
}

// Themed panel with a glowing border + drop shadow.
//   TESLA     — a BREATHING electric-blue border: stroke alpha, width and glow elevation
//               all pulse forever via an infinite transition.
//   STEAMPUNK — a STATIC brass border + steady drop shadow (no pulse, no electricity).
// Built with composed {} so it can hold the infinite transition (TESLA) while keeping a plain
// Modifier signature (no call-site changes).
fun Modifier.electricPanel(
    bg: Color = Theme.surface,
    corner: Dp = 4.dp,
    alpha: Float = 0.6f,
    elevation: Dp = 14.dp,
): Modifier = composed {
    val shape = RoundedCornerShape(corner)
    if (Theme.themeMode == ThemeMode.STEAMPUNK) {
        // Steady brass — no animation.
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .background(bg, shape)
            .border(1.6.dp, Theme.borderBrass.copy(alpha = (alpha + 0.2f).coerceAtMost(1f)), shape)
    } else {
        val t = rememberInfiniteTransition(label = "panel")
        val p by t.animateFloat(
            initialValue = 0f, targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(1700, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "pulse")
        this
            .shadow(elevation * (1.3f + 1.0f * p), shape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
            .background(bg, shape)
            .border((1.8f + 1.0f * p).dp, Theme.verdigris.copy(alpha = (alpha * (0.9f + 0.6f * p)).coerceAtMost(1f)), shape)
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
