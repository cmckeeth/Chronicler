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

// Six runtime themes:
//   TESLA     — electric-blue look (the current default; animated lightning everywhere).
//   STEAMPUNK — Victorian brass/gold, NO electricity (static brass borders, green accent).
//   GARDEN    — verdant greens + floral pink accents, NO electricity (soft solid panels,
//               rounded organic corners, steady soft-green glow, handwritten/rounded fonts).
//   ACADEMIA  — Dark Academia: espresso wood, brass metal, cream text, forest-green accent,
//               rain backdrop, elegant serif. NO electricity.
//   NOIR      — Blackletter Noir: near-black, tarnished-silver metal, cold-gray text,
//               ox-blood accent, drifting fog, sharp corners, dramatic serif. NO electricity.
//   WEST      — Wild West: sun-bleached desert dusk, leather browns, sheriff-star gold,
//               turquoise accent, mesas/tumbleweeds backdrop, wood-type + slab serif.
//               NO electricity.
enum class ThemeMode { TESLA, STEAMPUNK, GARDEN, ACADEMIA, NOIR, WEST }

// Theme palette. Every themed color is a computed `get()` that reads [themeMode], so any
// composable that touches a color recomposes when the mode flips (mutableStateOf is observed
// inside composition). Call sites are unchanged — `Theme.bg` still reads like a constant.
object Theme {
    // Backing state. Flip this to switch themes app-wide; MainActivity restores it on launch.
    var themeMode by mutableStateOf(ThemeMode.TESLA)

    private val tesla get() = themeMode == ThemeMode.TESLA
    private val garden get() = themeMode == ThemeMode.GARDEN

    // Pick a per-theme value. Order: TESLA, STEAMPUNK, GARDEN, ACADEMIA, NOIR, WEST.
    private fun <T> byTheme(tesla: T, steampunk: T, garden: T, academia: T, noir: T, west: T): T = when (themeMode) {
        ThemeMode.TESLA -> tesla
        ThemeMode.STEAMPUNK -> steampunk
        ThemeMode.GARDEN -> garden
        ThemeMode.ACADEMIA -> academia
        ThemeMode.NOIR -> noir
        ThemeMode.WEST -> west
    }

    // TESLA — cold futuristic glass/electric (dark blue-black, electric-blue "metal").
    // STEAMPUNK — warm Victorian brass/gold/leather, green accent.
    // GARDEN — verdant greens, foliage-green "metal", floral-pink accent.
    // ACADEMIA — espresso wood, antique-brass "metal", cream text, forest-green accent.
    // NOIR — near-black, tarnished-silver "metal", cold-gray text, ox-blood accent.
    //                            ( tesla     , steampunk  , garden     , academia   , noir       , west       )
    val bg: Color get() = byTheme(Color(0xFF05080F), Color(0xFF160D03), Color(0xFF0B1410), Color(0xFF161009), Color(0xFF040406), Color(0xFF150E08))
    val bg2: Color get() = byTheme(Color(0xFF090E1A), Color(0xFF1E1206), Color(0xFF0F1C14), Color(0xFF1D150C), Color(0xFF08080B), Color(0xFF1F150C))
    val leather: Color get() = byTheme(Color(0xFF0B1424), Color(0xFF281809), Color(0xFF12241A), Color(0xFF2A1D10), Color(0xFF0C0C10), Color(0xFF2B1D10))
    val surface: Color get() = byTheme(Color(0xFF0F1A2E), Color(0xFF32200C), Color(0xFF16301F), Color(0xFF2F2211), Color(0xFF101015), Color(0xFF362514))
    val surface2: Color get() = byTheme(Color(0xFF142440), Color(0xFF3E280E), Color(0xFF1D3D28), Color(0xFF3A2B16), Color(0xFF17171E), Color(0xFF442F1A))
    val surface3: Color get() = byTheme(Color(0xFF1B3052), Color(0xFF4A3012), Color(0xFF245031), Color(0xFF46351C), Color(0xFF212129), Color(0xFF543A20))
    val border: Color get() = byTheme(Color(0xFF21405F), Color(0xFF6B4420), Color(0xFF2F5C3C), Color(0xFF5A4527), Color(0xFF2E2E38), Color(0xFF6D4A28))
    val borderBrass: Color get() = byTheme(Color(0xFF3F86B8), Color(0xFFC08828), Color(0xFF6FAE5F), Color(0xFF9A7B3E), Color(0xFF7E818C), Color(0xFFC08A45))
    // "brass"/metal token (~used everywhere for buttons, wordmark). TESLA = electric blue/chrome,
    // GARDEN = foliage green, ACADEMIA = antique brass, NOIR = bone/tarnished silver.
    val brass: Color get() = byTheme(Color(0xFF2BC4FF), Color(0xFFE09808), Color(0xFF8BD450), Color(0xFFC39A4E), Color(0xFFC4C8D2), Color(0xFFD9A441))
    val brassLight: Color get() = byTheme(Color(0xFF7FE0FF), Color(0xFFFFC838), Color(0xFFB6F07A), Color(0xFFE3C275), Color(0xFFE2E5EC), Color(0xFFF0C46F))
    val brassPale: Color get() = byTheme(Color(0xFFD6F4FF), Color(0xFFFFE878), Color(0xFFE2FFC0), Color(0xFFF4E6B8), Color(0xFFF2F4F8), Color(0xFFFFE3AB))
    val copper: Color get() = byTheme(Color(0xFF1F9FD8), Color(0xFFC86818), Color(0xFFE88FA8), Color(0xFF7D9B6A), Color(0xFF6E0D13), Color(0xFFB4552B))
    val rust: Color get() = byTheme(Color(0xFFFF5470), Color(0xFFB82C0C), Color(0xFFD4564A), Color(0xFFA23B22), Color(0xFFC41019), Color(0xFFC0392B))
    // Accent / "electric" token. Name kept (used ~35 places). TESLA = electric blue,
    // STEAMPUNK = verdigris green, GARDEN = floral pink, ACADEMIA = forest green, NOIR = ox-blood.
    val verdigris: Color get() = byTheme(Color(0xFF2BC4FF), Color(0xFF8FD44A), Color(0xFFFF8FB8), Color(0xFF4F8A52), Color(0xFFA8121B), Color(0xFF3FB0A3))
    val parchment: Color get() = byTheme(Color(0xFFE6F3FF), Color(0xFFF6ECD0), Color(0xFFF0F7E8), Color(0xFFF2E7CF), Color(0xFFD9DBE2), Color(0xFFF3E3C3))
    val parchmentMid: Color get() = byTheme(Color(0xFFA6C8E2), Color(0xFFE0BC6C), Color(0xFFCFE4B8), Color(0xFFD4C29A), Color(0xFF9A9DA9), Color(0xFFD6B98A))
    val parchmentDim: Color get() = byTheme(Color(0xFF6F93B4), Color(0xFFC09838), Color(0xFF9BBF88), Color(0xFFA08F6E), Color(0xFF666974), Color(0xFFA8865C))
    val ink: Color get() = byTheme(Color(0xFF04101E), Color(0xFF1A0C02), Color(0xFF08130C), Color(0xFF120C06), Color(0xFF030304), Color(0xFF140C05))

    // Steady halo colors (no electricity, no pulse): GARDEN soft green, ACADEMIA green bloom,
    // NOIR bright ox-blood so the halo reads on near-black.
    private val gardenGlow get() = Color(0xFF7CC24A)
    private val academiaGlow get() = Color(0xFF5A9E5D)
    private val noirGlow get() = Color(0xFFC4202A)   // bright ox-blood halo on crypt-black
    private val westGlow get() = Color(0xFFE0A33F)   // warm lantern gold, not the turquoise accent

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
    // Blackletter Noir: heavy gothic textura wordmark.
    private val unifrakturDisplay = FontFamily(Font(R.font.unifraktur_maguntia))
    private val rajdhaniSerif = FontFamily(
        Font(R.font.rajdhani_semibold, FontWeight.Normal),
        Font(R.font.rajdhani_semibold, FontWeight.Bold),
    )
    private val loraBody = FontFamily(Font(R.font.lora))
    // WEST — wood-type wordmark (Rye) + slab-serif UI/body (Zilla Slab).
    private val ryeDisplay = FontFamily(Font(R.font.rye))
    private val zillaSlabBody = FontFamily(
        Font(R.font.zilla_slab, FontWeight.Normal),
        Font(R.font.zilla_slab_semibold, FontWeight.Bold),
    )
    private val zillaSlabSerif = FontFamily(Font(R.font.zilla_slab_semibold))
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

    // ACADEMIA + NOIR reuse the bundled serif family (Cinzel caps + Lora body) — both are
    // literary serif looks. ACADEMIA leans elegant (plain Cinzel wordmark); NOIR leans
    // dramatic (ornate Cinzel Decorative wordmark). Web gets bespoke Cormorant/Playfair/Pirata.
    val display: FontFamily get() = byTheme(orbitronDisplay, cinzelDisplay, dancingDisplay, cinzelSerif, unifrakturDisplay, ryeDisplay)
    val serif: FontFamily get() = byTheme(rajdhaniSerif, cinzelSerif, quicksandSerif, cinzelSerif, cinzelSerif, zillaSlabSerif)
    val body: FontFamily get() = byTheme(rajdhaniBody, loraBody, quicksandBody, loraBody, loraBody, zillaSlabBody)

    // Glows read the themed colors via get() so they re-evaluate when the mode flips.
    // STEAMPUNK headings get a warm brass halo; TESLA gets the bright electric-blue one;
    // GARDEN gets a steady soft-green halo (no electricity, no pulse).
    val glowBrass: Shadow get() = Shadow(color = brass.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 24f)
    val glowVerdigris: Shadow
        get() = byTheme(
            Shadow(color = verdigris.copy(alpha = 1f), offset = Offset.Zero, blurRadius = 36f),
            Shadow(color = brass.copy(alpha = 0.7f), offset = Offset.Zero, blurRadius = 18f),
            Shadow(color = gardenGlow.copy(alpha = 0.75f), offset = Offset.Zero, blurRadius = 22f),
            Shadow(color = academiaGlow.copy(alpha = 0.72f), offset = Offset.Zero, blurRadius = 22f),
            Shadow(color = noirGlow.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 16f),  // tighter = sharper
            Shadow(color = westGlow.copy(alpha = 0.8f), offset = Offset.Zero, blurRadius = 20f),
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
            .background(bg.copy(alpha = 0.5f), shape)
            .border(1.4.dp, Theme.borderBrass.copy(alpha = (alpha * 0.7f).coerceAtMost(1f)), shape)
    } else if (Theme.themeMode == ThemeMode.STEAMPUNK) {
        // Brass panel, tight 2.dp corners — slightly translucent so the factory skyline
        // backdrop reads through while staying legible. No animation, no glass.
        val shape = RoundedCornerShape(2.dp)
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .background(bg.copy(alpha = 0.5f), shape)
            .border(1.6.dp, Theme.borderBrass.copy(alpha = (alpha + 0.2f).coerceAtMost(1f)), shape)
    } else if (Theme.themeMode == ThemeMode.ACADEMIA) {
        // Academia: quiet leather-and-lamplight panel — softly squared 6.dp corners, a
        // brass-green border, steady warm shadow. No animation, no glass.
        val shape = RoundedCornerShape(6.dp)
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Theme.brass)
            .background(bg.copy(alpha = 0.55f), shape)
            .border(1.2.dp, Theme.borderBrass.copy(alpha = (alpha + 0.1f).coerceAtMost(1f)), shape)
    } else if (Theme.themeMode == ThemeMode.NOIR) {
        // Noir: sharp gothic plate — hard right-angle corners, a thin tarnished-silver edge,
        // and a hard black drop shadow. No animation, no glass, no bloom.
        val shape = RoundedCornerShape(0.dp)
        this
            .shadow(elevation, shape, spotColor = Color.Black, ambientColor = Color.Black)
            .background(bg.copy(alpha = 0.66f), shape)
            .border(1.dp, Theme.borderBrass.copy(alpha = (alpha + 0.15f).coerceAtMost(1f)), shape)
    } else if (Theme.themeMode == ThemeMode.WEST) {
        // West: a weathered board nailed up — squared 3.dp corners, thick sun-baked leather
        // edge, a warm dusk shadow. No animation, no glass.
        val shape = RoundedCornerShape(3.dp)
        this
            .shadow(elevation, shape, spotColor = Theme.brass, ambientColor = Color.Black)
            .background(bg.copy(alpha = 0.62f), shape)
            .border(1.6.dp, Theme.borderBrass.copy(alpha = (alpha + 0.15f).coerceAtMost(1f)), shape)
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
