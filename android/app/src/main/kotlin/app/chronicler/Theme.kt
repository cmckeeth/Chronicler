package app.chronicler

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

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
}

fun formatTime(seconds: Double): String {
    if (!seconds.isFinite() || seconds < 0) return "0:00"
    val total = seconds.toInt()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
