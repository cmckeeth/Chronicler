package app.chronicler

import android.content.Context
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Android Auto entry point. Auto doesn't render our Compose UI — it binds to this
// MediaLibraryService, asks for a browsable tree of the library, and drives playback
// through the session's player. Kept INDEPENDENT of the in-app AudioController: this
// owns its own ExoPlayer so the phone player is never disturbed. Both reconcile through
// the server's per-chapter progress (the same source the in-app screen resumes from).
//
// Auth: /books, /chapters, /progress need the JWT (read from the prefs AuthStore writes).
// /cover and /chapters/{id}/audio are public, so Auto loads artwork + streams audio by URL.
//
// Offline (no signal in the car): the library falls back to downloaded books, chapters play
// from disk, and progress is kept in the same progress.json the phone uses, marked dirty
// so the next online load pushes it.
@UnstableApi
class AutoPlaybackService : MediaLibraryService() {

    private val api = ApiClient()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var player: ExoPlayer
    private lateinit var session: MediaLibrarySession

    private var books: List<Book> = emptyList()
    private var pollJob: Job? = null
    private var lastSaveMs = 0L

    override fun onCreate() {
        super.onCreate()
        api.token = getSharedPreferences("chronicler", Context.MODE_PRIVATE).getString("token", null)

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, /* handleAudioFocus = */ true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .setSeekBackIncrementMs(SKIP_MS)        // Auto shows a 30s rewind button
            .setSeekForwardIncrementMs(SKIP_MS)     // Auto shows a 30s forward button
            .build()
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (!isPlaying) saveProgress(force = true)   // flush on pause/stop
            }
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                lastSaveMs = 0L                              // allow an immediate save on the new chapter
            }
        })

        session = MediaLibrarySession.Builder(this, player, LibraryCallback())
            .setId("ChroniclerAuto")
            .build()

        pollJob = scope.launch {
            while (true) { delay(5_000); saveProgress() }
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession = session

    override fun onDestroy() {
        pollJob?.cancel()
        session.release()
        player.release()
        scope.cancel()
        super.onDestroy()
    }

    // ── Progress sync ──
    private fun saveProgress(force: Boolean = false) {
        val item = player.currentMediaItem ?: return
        val chapterId = chapterIdFrom(item.mediaId) ?: return
        if (!force && !player.isPlaying) return
        val now = System.currentTimeMillis()
        if (!force && now - lastSaveMs < 10_000) return
        lastSaveMs = now
        val pos = player.currentPosition / 1000.0
        val dur = (player.duration.takeIf { it > 0 } ?: 0L) / 1000.0
        scope.launch {
            val saved = api.saveChapterProgress(chapterId, pos, dur)
            if (!saved || Downloads.isDownloaded(this@AutoPlaybackService, chapterId)) {
                val listened = (dur > 0 && pos / dur >= 0.95) ||
                    Downloads.localProgress(this@AutoPlaybackService, chapterId)?.isListened == true
                Downloads.setLocalProgress(this@AutoPlaybackService, chapterId, pos, dur, listened, dirty = !saved)
            }
        }
    }

    // Pushes progress recorded while offline (here or on the phone). Kept dirty if it fails.
    private suspend fun flushOfflineProgress() {
        Downloads.dirtyProgress(this).forEach { (chapterId, stored) ->
            if (!api.saveChapterProgress(chapterId, stored.positionSeconds, stored.durationSeconds)) return
            if (stored.isListened) api.completeChapter(chapterId)
            Downloads.clearDirty(this, chapterId)
        }
    }

    // Chapters from the server, or from the download manifest when it can't be reached
    // (then only the ones on disk, since the rest can't play). `offline` says which.
    private suspend fun chaptersFor(bookId: Int): Pair<List<Chapter>, Boolean> {
        val online = api.getChapters(bookId)
        if (online.isNotEmpty()) return online to false
        val local = Downloads.entry(this, bookId)?.chapters.orEmpty()
            .filter { Downloads.isDownloaded(this, it.id) }
        return local to true
    }

    // ── Library tree + playback resolution ──
    private inner class LibraryCallback : MediaLibrarySession.Callback {

        override fun onGetLibraryRoot(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            params: LibraryParams?
        ): ListenableFuture<LibraryResult<MediaItem>> {
            val root = MediaItem.Builder().setMediaId(ROOT_ID)
                .setMediaMetadata(MediaMetadata.Builder()
                    .setTitle("Chronicler")
                    .setIsBrowsable(true).setIsPlayable(false)
                    .setMediaType(MediaMetadata.MEDIA_TYPE_FOLDER_MIXED)
                    .build())
                .build()
            return Futures.immediateFuture(LibraryResult.ofItem(root, params))
        }

        override fun onGetChildren(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            parentId: String,
            page: Int,
            pageSize: Int,
            params: LibraryParams?
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> {
            val future = SettableFuture.create<LibraryResult<ImmutableList<MediaItem>>>()
            scope.launch {
                val items = if (parentId == ROOT_ID) loadBooks().map { bookItem(it) } else emptyList()
                future.set(LibraryResult.ofItemList(ImmutableList.copyOf(items), params))
            }
            return future
        }

        override fun onGetItem(
            session: MediaLibrarySession,
            browser: MediaSession.ControllerInfo,
            mediaId: String
        ): ListenableFuture<LibraryResult<MediaItem>> {
            val future = SettableFuture.create<LibraryResult<MediaItem>>()
            scope.launch {
                val item = bookIdFrom(mediaId)?.let { id -> loadBooks().firstOrNull { it.id == id } }?.let(::bookItem)
                future.set(
                    if (item != null) LibraryResult.ofItem(item, null)
                    else LibraryResult.ofError(LibraryResult.RESULT_ERROR_BAD_VALUE))
            }
            return future
        }

        // Tap a book in Auto → expand to its chapter playlist, resume at the first
        // unfinished chapter and its saved position.
        override fun onSetMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: MutableList<MediaItem>,
            startIndex: Int,
            startPositionMs: Long
        ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
            val bookId = mediaItems.firstOrNull()?.mediaId?.let(::bookIdFrom)
                ?: return Futures.immediateFuture(
                    MediaSession.MediaItemsWithStartPosition(mediaItems, startIndex, startPositionMs))

            val future = SettableFuture.create<MediaSession.MediaItemsWithStartPosition>()
            scope.launch {
                val book = loadBooks().firstOrNull { it.id == bookId }
                val (chapters, offline) = chaptersFor(bookId)
                if (chapters.isEmpty()) {
                    // Nothing playable (offline and not downloaded). Never hand the player the
                    // bare book item: it has no audio URI and the player throws on it.
                    future.set(MediaSession.MediaItemsWithStartPosition(emptyList(), C.INDEX_UNSET, C.TIME_UNSET))
                    return@launch
                }
                val progresses = if (offline) chapters.map { ch ->
                    Downloads.localProgress(this@AutoPlaybackService, ch.id)
                        .let { ChapterProgress(it?.positionSeconds ?: 0.0, it?.isListened ?: false) }
                } else coroutineScope {
                    chapters.map { async { api.getChapterProgress(it.id) } }.awaitAll()
                }
                var idx = progresses.indexOfFirst { !it.isListened }
                if (idx < 0) idx = 0
                val startPos = ((progresses.getOrNull(idx)?.positionSeconds ?: 0.0) * 1000).toLong()
                val items = chapters.map { chapterItem(it, book) }
                future.set(MediaSession.MediaItemsWithStartPosition(items, idx, startPos))
            }
            return future
        }

        // Fallback path (e.g. queue restore): resolve bare ids back into playable URIs.
        override fun onAddMediaItems(
            mediaSession: MediaSession,
            controller: MediaSession.ControllerInfo,
            mediaItems: MutableList<MediaItem>
        ): ListenableFuture<MutableList<MediaItem>> {
            val future = SettableFuture.create<MutableList<MediaItem>>()
            scope.launch {
                val out = ArrayList<MediaItem>()
                for (mi in mediaItems) {
                    val bid = bookIdFrom(mi.mediaId)
                    val cid = chapterIdFrom(mi.mediaId)
                    when {
                        bid != null -> {
                            val book = loadBooks().firstOrNull { it.id == bid }
                            out += chaptersFor(bid).first.map { chapterItem(it, book) }
                        }
                        cid != null && mi.localConfiguration == null -> out += mi.buildUpon()
                            .setUri(Downloads.sourceUri(this@AutoPlaybackService, cid, api.audioUrl(cid))).build()
                        mi.localConfiguration != null -> out += mi
                        // Anything else has no audio to play; leave it out rather than crash the player.
                    }
                }
                future.set(out)
            }
            return future
        }
    }

    // ── Item builders ──
    private fun bookItem(b: Book): MediaItem {
        val meta = MediaMetadata.Builder()
            .setTitle(b.title)
            .setArtist(b.author)
            .setSubtitle(b.narrator ?: b.author)
            .setIsBrowsable(false).setIsPlayable(true)
            .setMediaType(MediaMetadata.MEDIA_TYPE_AUDIO_BOOK)
            .apply { if (b.hasCover) setArtworkUri(Uri.parse(api.coverUrl(b.id))) }
            .build()
        return MediaItem.Builder().setMediaId("book:${b.id}").setMediaMetadata(meta).build()
    }

    private fun chapterItem(ch: Chapter, book: Book?): MediaItem {
        val meta = MediaMetadata.Builder()
            .setTitle(ch.title)
            .setArtist(book?.author ?: "")
            .setAlbumTitle(book?.title)
            .setIsBrowsable(false).setIsPlayable(true)
            .setMediaType(MediaMetadata.MEDIA_TYPE_AUDIO_BOOK_CHAPTER)
            .apply { if (book?.hasCover == true) setArtworkUri(Uri.parse(api.coverUrl(book.id))) }
            .build()
        return MediaItem.Builder()
            .setMediaId("chapter:${ch.id}")
            .setUri(Downloads.sourceUri(this, ch.id, api.audioUrl(ch.id)))   // local file when downloaded
            .setMimeType(ch.mimeType)
            .setMediaMetadata(meta)
            .build()
    }

    private suspend fun loadBooks(): List<Book> {
        if (books.isEmpty()) {
            val online = api.getBooks()
            if (online.isEmpty()) {
                // Server unreachable: list what's downloaded. Not cached, so the full
                // library comes back as soon as there's signal again.
                return Downloads.downloadedBooks(this).map { it.book }
            }
            books = online.sortedWith(
                compareByDescending<Book> { it.isFavorite }
                    .thenByDescending { it.isInProgress }
                    .thenBy { it.title.lowercase() })
            flushOfflineProgress()
        }
        return books
    }

    companion object {
        private const val ROOT_ID = "root"
        private const val SKIP_MS = 30_000L

        private fun bookIdFrom(mediaId: String?): Int? =
            mediaId?.takeIf { it.startsWith("book:") }?.removePrefix("book:")?.toIntOrNull()

        private fun chapterIdFrom(mediaId: String?): Int? =
            mediaId?.takeIf { it.startsWith("chapter:") }?.removePrefix("chapter:")?.toIntOrNull()
    }
}
