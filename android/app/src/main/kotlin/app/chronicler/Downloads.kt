package app.chronicler

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File

// A book whose chapters have been downloaded: enough metadata to list and play it with
// the server unreachable. Written to manifest.json beside the audio files.
@Serializable
data class DownloadedBook(val book: Book, val chapters: List<Chapter>)

// Chapter progress kept on disk so offline playback resumes in the right place.
// `dirty` marks progress recorded while the server was unreachable; it gets pushed on
// the next load that reaches the API.
@Serializable
data class StoredProgress(
    val positionSeconds: Double = 0.0,
    val durationSeconds: Double = 0.0,
    val isListened: Boolean = false,
    val dirty: Boolean = false,
)

// Offline downloads: stores chapter audio under filesDir/downloads/<chapterId>.audio, the
// book + chapter metadata in manifest.json, the cover in cover-<bookId>.img and chapter
// progress in progress.json — so the whole offline library works with no network at all.
object Downloads {
    private val http = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val lock = Any()

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
        dir(context).listFiles()?.filter { it.name.endsWith(".audio") }
            ?.sumOf { it.length() } ?: 0L
    }

    // ── Manifest (which books/chapters the downloads belong to) ──

    private fun manifestFile(context: Context) = File(dir(context), "manifest.json")

    private fun readManifest(context: Context): MutableMap<String, DownloadedBook> = runCatching {
        val f = manifestFile(context)
        if (!f.exists()) return@runCatching mutableMapOf<String, DownloadedBook>()
        json.decodeFromString<Map<String, DownloadedBook>>(f.readText()).toMutableMap()
    }.getOrDefault(mutableMapOf())

    private fun writeManifest(context: Context, manifest: Map<String, DownloadedBook>) {
        runCatching { manifestFile(context).writeText(json.encodeToString<Map<String, DownloadedBook>>(manifest)) }
    }

    /** Remembers a book + its chapter list so the offline library can list and play it. */
    fun record(context: Context, book: Book, chapters: List<Chapter>) {
        if (chapters.isEmpty()) return
        synchronized(lock) {
            val manifest = readManifest(context)
            manifest[book.id.toString()] = DownloadedBook(book, chapters)
            writeManifest(context, manifest)
        }
    }

    fun entry(context: Context, bookId: Int): DownloadedBook? =
        synchronized(lock) { readManifest(context)[bookId.toString()] }

    /** Books with at least one chapter still on disk, A→Z by title. */
    fun downloadedBooks(context: Context): List<DownloadedBook> =
        synchronized(lock) { readManifest(context).values.toList() }
            .filter { entry -> entry.chapters.any { isDownloaded(context, it.id) } }
            .sortedBy { it.book.title.lowercase() }

    /** Cheap check: is anything downloaded at all? */
    fun hasAny(context: Context): Boolean =
        dir(context).listFiles()?.any { it.name.endsWith(".audio") && it.length() > 0 } ?: false

    fun downloadedCount(context: Context, bookId: Int): Int =
        entry(context, bookId)?.chapters?.count { isDownloaded(context, it.id) } ?: 0

    fun bookSize(context: Context, bookId: Int): Long =
        entry(context, bookId)?.chapters?.sumOf { file(context, it.id).length() } ?: 0L

    /** Deletes every downloaded chapter of a book plus its cached cover + manifest entry. */
    fun purgeBook(context: Context, bookId: Int) {
        entry(context, bookId)?.chapters?.forEach { deleteChapter(context, it.id) }
        coverFile(context, bookId).delete()
        synchronized(lock) {
            val manifest = readManifest(context)
            manifest.remove(bookId.toString())
            writeManifest(context, manifest)
        }
    }

    /** Drops the manifest entry once the last chapter of a book has been removed. */
    fun pruneIfEmpty(context: Context, bookId: Int) {
        val entry = entry(context, bookId) ?: return
        if (entry.chapters.none { isDownloaded(context, it.id) }) purgeBook(context, bookId)
    }

    // ── Cover (kept beside the audio so the offline library isn't a wall of placeholders) ──

    fun coverFile(context: Context, bookId: Int): File = File(dir(context), "cover-$bookId.img")

    fun coverBytes(context: Context, bookId: Int): ByteArray? =
        coverFile(context, bookId).let { if (it.exists() && it.length() > 0) it.readBytes() else null }

    /** Fetches and stores the cover for a downloaded book (no-op if it can't be fetched). */
    suspend fun cacheCover(context: Context, bookId: Int, api: ApiClient) {
        val bytes = api.coverBytes(bookId) ?: return
        withContext(Dispatchers.IO) { runCatching { coverFile(context, bookId).writeBytes(bytes) } }
    }

    // ── Local chapter progress ──

    private fun progressFile(context: Context) = File(dir(context), "progress.json")

    private fun readProgress(context: Context): MutableMap<String, StoredProgress> = runCatching {
        val f = progressFile(context)
        if (!f.exists()) return@runCatching mutableMapOf<String, StoredProgress>()
        json.decodeFromString<Map<String, StoredProgress>>(f.readText()).toMutableMap()
    }.getOrDefault(mutableMapOf())

    private fun writeProgress(context: Context, progress: Map<String, StoredProgress>) {
        runCatching { progressFile(context).writeText(json.encodeToString<Map<String, StoredProgress>>(progress)) }
    }

    fun localProgress(context: Context, chapterId: Int): StoredProgress? =
        synchronized(lock) { readProgress(context)[chapterId.toString()] }

    fun setLocalProgress(context: Context, chapterId: Int, position: Double, duration: Double,
                         isListened: Boolean, dirty: Boolean) {
        synchronized(lock) {
            val progress = readProgress(context)
            val existing = progress[chapterId.toString()]
            progress[chapterId.toString()] = StoredProgress(
                positionSeconds = position,
                durationSeconds = if (duration > 0) duration else (existing?.durationSeconds ?: 0.0),
                isListened = isListened,
                dirty = dirty,
            )
            writeProgress(context, progress)
        }
    }

    /** Progress recorded while offline, keyed by chapter id. */
    fun dirtyProgress(context: Context): Map<Int, StoredProgress> =
        synchronized(lock) { readProgress(context) }
            .filterValues { it.dirty }
            .mapNotNull { (k, v) -> k.toIntOrNull()?.let { it to v } }
            .toMap()

    fun clearDirty(context: Context, chapterId: Int) {
        synchronized(lock) {
            val progress = readProgress(context)
            progress[chapterId.toString()]?.let {
                progress[chapterId.toString()] = it.copy(dirty = false)
                writeProgress(context, progress)
            }
        }
    }
}
