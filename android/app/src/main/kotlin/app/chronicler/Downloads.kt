package app.chronicler

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File

// Offline downloads: stores chapter audio under filesDir/downloads/<chapterId>.audio
// and serves a local file URI when present so playback works without the network.
object Downloads {
    private val http = OkHttpClient()

    private fun dir(context: Context): File =
        File(context.filesDir, "downloads").apply { mkdirs() }

    fun file(context: Context, chapterId: Int): File = File(dir(context), "$chapterId.audio")

    fun isDownloaded(context: Context, chapterId: Int): Boolean =
        file(context, chapterId).let { it.exists() && it.length() > 0 }

    /** Local file URI if downloaded, else the streaming URL. */
    fun sourceUri(context: Context, chapterId: Int, streamUrl: String): String =
        if (isDownloaded(context, chapterId)) Uri.fromFile(file(context, chapterId)).toString() else streamUrl

    suspend fun download(context: Context, chapterId: Int, url: String): Boolean =
        withContext(Dispatchers.IO) {
            runCatching {
                val resp = http.newCall(Request.Builder().url(url).build()).execute()
                resp.use {
                    if (!it.isSuccessful) return@withContext false
                    val tmp = File(dir(context), "$chapterId.part")
                    it.body?.byteStream()?.use { input ->
                        tmp.outputStream().use { out -> input.copyTo(out) }
                    } ?: return@withContext false
                    if (tmp.length() <= 0) { tmp.delete(); return@withContext false }
                    tmp.renameTo(file(context, chapterId))
                }
                true
            }.getOrDefault(false)
        }

    fun deleteChapter(context: Context, chapterId: Int) {
        file(context, chapterId).delete()
    }

    fun deleteBook(context: Context, chapterIds: List<Int>) {
        chapterIds.forEach { deleteChapter(context, it) }
    }

    suspend fun totalSize(context: Context): Long = withContext(Dispatchers.IO) {
        dir(context).listFiles()?.sumOf { it.length() } ?: 0L
    }
}
