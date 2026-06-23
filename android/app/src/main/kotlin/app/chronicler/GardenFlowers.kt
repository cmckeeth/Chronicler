package app.chronicler

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp

// One real painted rose (rose head + leafy stem on transparency). It grows IN on first
// composition: revealed from its bottom edge upward (leafy stem grows up, bloom rises into
// view), staggered, then sways gently forever, pivoting on its base (transform-origin
// bottom). Non-interactive background ornament.
@Composable
private fun BoxScope.Rose(
    sizeDp: Int,
    align: Alignment,
    xDp: Int,
    yDp: Int,
    growDelayMs: Int,
    swayMs: Int,
    swayDeg: Float,
    reverse: Boolean,
) {
    // Grow-in: bottom-up reveal 0 -> 1, staggered by growDelayMs (stem grows up, bloom rises).
    var grown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { grown = true }
    val grow by animateFloatAsState(
        targetValue = if (grown) 1f else 0f,
        animationSpec = tween(durationMillis = 2200, delayMillis = growDelayMs, easing = FastOutSlowInEasing),
        label = "roseGrow",
    )

    // Gentle continuous sway, pivoting on the base of the stem.
    val t = rememberInfiniteTransition(label = "roseSway")
    val deg by t.animateFloat(
        initialValue = if (reverse) swayDeg else -swayDeg,
        targetValue = if (reverse) -swayDeg else swayDeg,
        animationSpec = infiniteRepeatable(tween(swayMs, easing = LinearEasing), RepeatMode.Reverse),
        label = "sway",
    )

    Image(
        painter = painterResource(R.drawable.rose),
        contentDescription = null,
        contentScale = ContentScale.Fit,
        modifier = Modifier
            .align(align)
            .offset(x = xDp.dp, y = yDp.dp)
            .size(sizeDp.dp)
            .graphicsLayer {
                // Pivot at the bottom-center so the sway roots at the base of the stem.
                transformOrigin = TransformOrigin(0.5f, 1f)
                rotationZ = deg
            }
            .drawWithContent {
                // Reveal from the bottom edge upward: only the lower `grow` fraction is drawn.
                val h = size.height * grow
                clipRect(top = size.height - h) { this@drawWithContent.drawContent() }
            },
    )
}

// GARDEN-only soft BACKGROUND wallpaper: several real painted roses standing along the BOTTOM
// of the screen (a row rising up), plus a couple of larger ones set back in the side margins.
// All at ~50% opacity so the panels read through. Each grows in (staggered) and sways gently.
// Mirrors the web GardenFX rose layer. Non-interactive (drawn behind content).
@Composable
fun GardenFlowerBackdrop(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().alpha(0.5f)) {
        // Larger roses set back in the side margins.
        Rose(sizeDp = 340, align = Alignment.BottomStart, xDp = -120, yDp = 40, growDelayMs = 0, swayMs = 11000, swayDeg = 2.5f, reverse = false)
        Rose(sizeDp = 320, align = Alignment.BottomEnd, xDp = 120, yDp = 40, growDelayMs = 120, swayMs = 12500, swayDeg = 2.5f, reverse = true)

        // A row of roses standing along the bottom, rising up (staggered grow-in).
        Rose(sizeDp = 170, align = Alignment.BottomStart, xDp = 4, yDp = 20, growDelayMs = 240, swayMs = 8000, swayDeg = 3.5f, reverse = true)
        Rose(sizeDp = 210, align = Alignment.BottomStart, xDp = 110, yDp = 30, growDelayMs = 360, swayMs = 9000, swayDeg = 3f, reverse = false)
        Rose(sizeDp = 240, align = Alignment.BottomCenter, xDp = -20, yDp = 24, growDelayMs = 480, swayMs = 9500, swayDeg = 3f, reverse = true)
        Rose(sizeDp = 200, align = Alignment.BottomCenter, xDp = 130, yDp = 32, growDelayMs = 600, swayMs = 8500, swayDeg = 3.5f, reverse = false)
        Rose(sizeDp = 215, align = Alignment.BottomEnd, xDp = -90, yDp = 28, growDelayMs = 720, swayMs = 9200, swayDeg = 3f, reverse = true)
        Rose(sizeDp = 165, align = Alignment.BottomEnd, xDp = 6, yDp = 20, growDelayMs = 840, swayMs = 7800, swayDeg = 3.5f, reverse = false)
    }
}
