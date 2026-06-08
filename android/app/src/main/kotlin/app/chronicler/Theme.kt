package app.chronicler

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
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

// Steampunk palette ported from steampunk.css :root
object Theme {
    val bg = Color(0xFF120A02)
    val bg2 = Color(0xFF1A1005)
    val leather = Color(0xFF221408)
    val surface = Color(0xFF2A1A0A)
    val surface2 = Color(0xFF341F0C)
    val surface3 = Color(0xFF3E260E)
    val border = Color(0xFF5A3418)
    val borderBrass = Color(0xFFB87C20)
    val brass = Color(0xFFE8A010)
    val brassLight = Color(0xFFFFC030)
    val brassPale = Color(0xFFFFE060)
    val copper = Color(0xFFD07020)
    val rust = Color(0xFFC03010)
    val verdigris = Color(0xFF8FD44A)
    val parchment = Color(0xFFFFF4D8)
    val parchmentMid = Color(0xFFE8C878)
    val parchmentDim = Color(0xFFC8A048)
    val ink = Color(0xFF1A0C02)

    val brassGradient = Brush.verticalGradient(listOf(brassLight, brass, borderBrass))

    // Fonts ported from steampunk.css: Cinzel Decorative (display), Cinzel (serif), Lora (body).
    val display = FontFamily(
        Font(R.font.cinzel_decorative_regular, FontWeight.Normal),
        Font(R.font.cinzel_decorative_bold, FontWeight.Bold),
        Font(R.font.cinzel_decorative_black, FontWeight.Black),
    )
    val serif = FontFamily(Font(R.font.cinzel))
    val body = FontFamily(Font(R.font.lora))

    // --glow-brass: 0 0 20px #e8a010 — the "electric" brass glow on headings/titles.
    val glowBrass = Shadow(color = brass.copy(alpha = 0.85f), offset = Offset.Zero, blurRadius = 24f)
    val glowVerdigris = Shadow(color = verdigris.copy(alpha = 0.9f), offset = Offset.Zero, blurRadius = 16f)
}

// Green-electric panel: verdigris drop-glow + filled background + verdigris border,
// in the right draw order. Slap it on containers for that old-MAUI electric rizz.
fun Modifier.electricPanel(
    bg: Color = Theme.surface,
    corner: Dp = 4.dp,
    alpha: Float = 0.6f,
    elevation: Dp = 14.dp,
): Modifier {
    val shape = RoundedCornerShape(corner)
    return this
        .shadow(elevation, shape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
        .background(bg, shape)
        .border(1.5.dp, Theme.verdigris.copy(alpha = alpha), shape)
}

fun formatTime(seconds: Double): String {
    if (!seconds.isFinite() || seconds < 0) return "0:00"
    val total = seconds.toInt()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
