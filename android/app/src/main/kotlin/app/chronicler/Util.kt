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
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.sp
import java.util.concurrent.ConcurrentHashMap

private val coverCache = ConcurrentHashMap<Int, ImageBitmap>()

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
                modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        } else {
            Text(if (book.hasCover) "⚙" else "📚", fontSize = 36.sp)
        }
    }
}

fun invalidateCover(bookId: Int) { coverCache.remove(bookId) }

// Startup sound (commit: "Play startup sound on app open").
object StartupSound {
    private var played = false          // once per app launch, not every time Landing recomposes
    fun play(context: Context) {
        if (played) return
        played = true
        runCatching {
            MediaPlayer.create(context, R.raw.startup)?.apply {
                setOnCompletionListener { it.release() }
                start()
            }
        }
    }
}
