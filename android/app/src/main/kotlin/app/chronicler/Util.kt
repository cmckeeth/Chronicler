package app.chronicler

import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaPlayer
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.sp
import java.util.concurrent.ConcurrentHashMap

private val coverCache = ConcurrentHashMap<Int, ImageBitmap>()

// Per-theme color treatment for book covers, mirroring the web app's cover filters.
//   TESLA     — cool/crisp: saturation ~1.08 + a slight contrast bump, no tint.
//   STEAMPUNK — aged sepia: desaturated (~.5), warm #d8b070 multiply, brightness ~.88.
//   GARDEN    — lush: saturation ~1.15 + a slight contrast bump.
// Returns null only if we ever add a "no filter" theme; callers apply it to Image.
fun coverColorFilter(): ColorFilter {
    fun saturate(m: ColorMatrix, s: Float) = m.apply { setToSaturation(s) }
    // contrast around 0.5 mid-grey: out = (in - 0.5) * c + 0.5, scaled to 0..255.
    fun contrast(c: Float): ColorMatrix {
        val t = (1f - c) * 0.5f * 255f
        return ColorMatrix(floatArrayOf(
            c, 0f, 0f, 0f, t,
            0f, c, 0f, 0f, t,
            0f, 0f, c, 0f, t,
            0f, 0f, 0f, 1f, 0f,
        ))
    }
    return when (Theme.themeMode) {
        ThemeMode.TESLA -> {
            val m = ColorMatrix().also { saturate(it, 1.08f) }
            m.timesAssign(contrast(1.05f))
            ColorFilter.colorMatrix(m)
        }
        ThemeMode.STEAMPUNK -> {
            // desaturate, warm-tint multiply (#d8b070 ≈ 0.847,0.690,0.439), dim brightness.
            val m = ColorMatrix().also { saturate(it, 0.5f) }
            val b = 0.88f
            val tint = ColorMatrix(floatArrayOf(
                0.847f * b, 0f, 0f, 0f, 0f,
                0f, 0.690f * b, 0f, 0f, 0f,
                0f, 0f, 0.439f * b, 0f, 0f,
                0f, 0f, 0f, 1f, 0f,
            ))
            m.timesAssign(tint)
            ColorFilter.colorMatrix(m)
        }
        ThemeMode.GARDEN -> {
            val m = ColorMatrix().also { saturate(it, 1.15f) }
            m.timesAssign(contrast(1.04f))
            ColorFilter.colorMatrix(m)
        }
    }
}

@Composable
fun CoverImage(book: Book, api: ApiClient, modifier: Modifier = Modifier) {
    var image by remember(book.id) { mutableStateOf(coverCache[book.id]) }

    androidx.compose.runtime.LaunchedEffect(book.id) {
        if (image == null && book.hasCover) {
            api.coverBytes(book.id)?.let { bytes ->
                val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bmp != null) {
                    val ib = bmp.asImageBitmap()
                    coverCache[book.id] = ib
                    image = ib
                }
            }
        }
    }

    Box(modifier = modifier.background(Theme.surface2), contentAlignment = Alignment.Center) {
        val img = image
        if (img != null) {
            Image(bitmap = img, contentDescription = book.title,
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop,
                colorFilter = coverColorFilter())
        } else {
            Text(if (book.hasCover) "⚙" else "📚", fontSize = 36.sp)
        }
    }
}

fun invalidateCover(bookId: Int) { coverCache.remove(bookId) }

// Collection covers share the same per-theme treatment as book covers. Keyed separately
// from the book cache to avoid id collisions between books and collections.
private val collectionCoverCache = ConcurrentHashMap<Int, ImageBitmap>()

@Composable
fun CollectionCover(collection: Collection, api: ApiClient, modifier: Modifier = Modifier) {
    var image by remember(collection.id) { mutableStateOf(collectionCoverCache[collection.id]) }

    androidx.compose.runtime.LaunchedEffect(collection.id) {
        if (image == null && collection.hasCover) {
            api.collectionCoverBytes(collection.id)?.let { bytes ->
                val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bmp != null) {
                    val ib = bmp.asImageBitmap()
                    collectionCoverCache[collection.id] = ib
                    image = ib
                }
            }
        }
    }

    Box(modifier = modifier.background(Theme.surface2), contentAlignment = Alignment.Center) {
        val img = image
        if (img != null) {
            Image(bitmap = img, contentDescription = collection.name,
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop,
                colorFilter = coverColorFilter())
        } else {
            Text(if (collection.hasCover) "⚙" else "📚", fontSize = 36.sp)
        }
    }
}

// Startup sound (commit: "Play startup sound on app open").
object StartupSound {
    private var played = false          // once per app launch, not every time Landing recomposes
    fun play(context: Context) {
        if (played) return
        played = true
        runCatching {
            // Per-theme sound (startup_tesla / startup_steampunk / startup_garden); fall
            // back to the generic startup.mp3 if a themed raw resource isn't present yet.
            val themed = context.resources.getIdentifier(
                "startup_${Theme.themeMode.name.lowercase()}", "raw", context.packageName)
            val resId = if (themed != 0) themed else R.raw.startup
            MediaPlayer.create(context, resId)?.apply {
                setOnCompletionListener { it.release() }
                start()
            }
        }
    }
}
