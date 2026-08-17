package app.chronicler

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun BookPlayerScreen(auth: AuthStore, nav: NavController, bookId: Int) {
    val context = LocalContext.current
    val api = auth.api
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val audio = remember { AudioController(context) }

    var book by remember { mutableStateOf<Book?>(null) }
    var chapters by remember { mutableStateOf<List<Chapter>>(emptyList()) }
    var progresses by remember { mutableStateOf<List<ChapterProgress>>(emptyList()) }
    var current by remember { mutableStateOf<Chapter?>(null) }
    var showMeta by remember { mutableStateOf(false) }
    var showInfo by remember { mutableStateOf(false) }
    var menuChapterId by remember { mutableStateOf<Int?>(null) }
    var editChapter by remember { mutableStateOf<Chapter?>(null) }
    // Download state per chapter: 0 = none, 1 = downloading, 2 = downloaded.
    val downloads = remember { mutableStateMapOf<Int, Int>() }
    // True when the book was opened from the offline manifest because the server couldn't
    // be reached: everything comes off disk and nothing is written back.
    var offline by remember { mutableStateOf(false) }

    // Saves the book + chapter metadata (and its cover) alongside the audio so the offline
    // library can list and play it with the server down.
    suspend fun rememberForOffline() {
        val b = book ?: return
        Downloads.record(context, b, chapters)
        Downloads.cacheCover(context, b.id, api)
    }

    fun loadChapter(ch: Chapter, start: Double) {
        current = ch
        // Play the local file when downloaded; otherwise stream.
        audio.load(Downloads.sourceUri(context, ch.id, api.audioUrl(ch.id)), ch.title, start, ch.mimeType)
    }

    fun downloadChapter(ch: Chapter) {
        downloads[ch.id] = 1
        scope.launch {
            val ok = Downloads.download(context, ch.id, api.audioUrl(ch.id))
            downloads[ch.id] = if (ok) 2 else 0
            if (ok) rememberForOffline()
        }
    }
    fun removeDownload(ch: Chapter) {
        Downloads.deleteChapter(context, ch.id)
        downloads[ch.id] = 0
        Downloads.pruneIfEmpty(context, bookId)
    }
    fun downloadAll() {
        scope.launch {
            var any = false
            for (ch in chapters) {
                if (downloads[ch.id] == 2) continue
                downloads[ch.id] = 1
                val ok = Downloads.download(context, ch.id, api.audioUrl(ch.id))
                downloads[ch.id] = if (ok) 2 else 0
                any = any || ok
            }
            if (any) rememberForOffline()
        }
    }
    fun removeAll() { chapters.forEach { removeDownload(it) } }

    LaunchedEffect(bookId) {
        audio.onProgress = { pos ->
            scope.launch {
                current?.let { cur ->
                    val dur = audio.duration
                    val idx = chapters.indexOfFirst { it.id == cur.id }
                    val finished = dur > 0 && pos / dur >= 0.95        // 95% = finished
                    val listened = finished || (idx >= 0 && progresses[idx].isListened)
                    // Always record locally so an offline session resumes where it left off;
                    // when offline the entry is marked dirty and pushed on the next online load.
                    if (Downloads.isDownloaded(context, cur.id)) {
                        Downloads.setLocalProgress(context, cur.id, pos, dur, listened, dirty = offline)
                    }
                    if (!offline) {
                        api.saveChapterProgress(cur.id, pos, dur)      // send real duration so server marks finished
                    }
                    if (idx >= 0) {
                        progresses = progresses.toMutableList().also {
                            it[idx] = it[idx].copy(positionSeconds = pos,
                                isListened = it[idx].isListened || finished)
                        }
                    }
                }
            }
        }
        audio.onEnded = end@{
            val cur = current ?: return@end
            val idx = chapters.indexOfFirst { it.id == cur.id }
            if (idx < 0) return@end
            // Offline, skip over any chapter that isn't on disk.
            val next = (idx + 1 until chapters.size).firstOrNull {
                !offline || Downloads.isDownloaded(context, chapters[it].id)
            } ?: return@end
            progresses = progresses.toMutableList().also { it[idx] = it[idx].copy(isListened = true) }
            loadChapter(chapters[next], 0.0)
            if (auth.autoplayNext) audio.play()   // continue into the next chapter
        }

        audio.setBoost(auth.volumeBoosted)

        val fetched = api.getBook(bookId)
        if (fetched != null) {
            book = fetched
        } else {
            // Server unreachable — fall back to what was saved with the download.
            val entry = Downloads.entry(context, bookId) ?: return@LaunchedEffect
            book = entry.book
            offline = true
        }

        if (!offline) chapters = api.getChapters(bookId)
        if (chapters.isEmpty()) chapters = Downloads.entry(context, bookId)?.chapters ?: emptyList()

        if (offline) {
            // Everything off disk: the positions saved while offline.
            progresses = chapters.map { ch ->
                val stored = Downloads.localProgress(context, ch.id)
                ChapterProgress(stored?.positionSeconds ?: 0.0, stored?.isListened ?: false)
            }
        } else {
            // Push anything recorded while the server was unreachable, then read it back.
            Downloads.dirtyProgress(context).forEach { (chapterId, stored) ->
                api.saveChapterProgress(chapterId, stored.positionSeconds, stored.durationSeconds)
                if (stored.isListened) api.completeChapter(chapterId)
                Downloads.clearDirty(context, chapterId)
            }
            // Load all chapter statuses in parallel so they show immediately on open.
            progresses = coroutineScope {
                chapters.map { ch -> async { api.getChapterProgress(ch.id) } }.awaitAll()
            }
            // Mirror to disk so the offline library resumes at the same spot.
            chapters.forEachIndexed { i, ch ->
                if (Downloads.isDownloaded(context, ch.id)) {
                    Downloads.setLocalProgress(context, ch.id, progresses[i].positionSeconds, 0.0,
                        progresses[i].isListened, dirty = false)
                }
            }
        }
        chapters.forEach { downloads[it.id] = if (Downloads.isDownloaded(context, it.id)) 2 else 0 }
        if (chapters.isNotEmpty()) {
            // Resume at the FIRST chapter that isn't completed (earliest unfinished),
            // picking up at its saved position. Offline, only chapters on disk qualify.
            val playable = chapters.indices.filter {
                !offline || Downloads.isDownloaded(context, chapters[it].id)
            }
            val idx = playable.firstOrNull { !progresses[it].isListened }
                ?: playable.firstOrNull() ?: return@LaunchedEffect
            loadChapter(chapters[idx], progresses[idx].positionSeconds)
        }
    }

    DisposableEffect(Unit) { onDispose { audio.release() } }

    // Keep the electric backdrop calm here until playback starts; restore on leaving.
    LaunchedEffect(audio.isPlaying) { ElectricState.suppressed = !audio.isPlaying }
    DisposableEffect(Unit) { onDispose { ElectricState.suppressed = false } }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())
        .padding(horizontal = 20.dp, vertical = 12.dp)) {
        TextButton(onClick = { nav.popBackStack() }, contentPadding = PaddingValues(0.dp)) {
            Text("‹ Library", color = Theme.brass)
        }
        Spacer(Modifier.height(8.dp))
        val b = book
        // Shown when the book was opened from disk because the server couldn't be reached.
        if (offline && b != null) {
            Row(Modifier.fillMaxWidth()
                .background(Theme.surface2, RoundedCornerShape(4.dp))
                .padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("📱", fontSize = 13.sp)
                Text("Offline — playing downloaded chapters. Progress syncs when the server returns.",
                    color = Theme.parchmentDim, fontSize = 12.sp)
            }
            Spacer(Modifier.height(8.dp))
        }
        if (b == null) {
            Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                Text("Consulting the archive...", color = Theme.parchmentDim)
            }
        } else {
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.Top) {
                CoverImage(b, api, Modifier.size(120.dp).clip(RoundedCornerShape(4.dp))
                    .clickable { if (!offline) scope.launch { showMeta = true } })   // editing needs the server
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f).clickable { showInfo = true }) {
                    Text(b.title, color = Theme.parchment, fontSize = 18.sp, fontWeight = FontWeight.Bold,
                        fontFamily = Theme.body)
                    Spacer(Modifier.height(6.dp))
                    // Single flowing byline so a long narrator wraps as text, not char-by-char.
                    Text(buildAnnotatedString {
                        withStyle(SpanStyle(color = Theme.parchmentMid)) { append(b.author) }
                        b.narrator?.let {
                            withStyle(SpanStyle(color = Theme.parchmentDim)) { append(" · $it") }
                        }
                    }, fontSize = 13.sp)
                    b.description?.takeIf { it.isNotBlank() }?.let {
                        Spacer(Modifier.height(8.dp))
                        Text(it, color = Theme.parchmentDim, fontSize = 12.sp, fontFamily = Theme.serif,
                            lineHeight = 17.sp, maxLines = 4,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                        Spacer(Modifier.height(4.dp))
                        Text("Read more ›", color = Theme.brass, fontSize = 11.sp)
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
            if (current != null) AudioPlayerBar(audio, auth)

            Spacer(Modifier.height(24.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Chapters", color = Theme.brass, fontSize = 16.sp, fontFamily = Theme.serif,
                    style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
                    modifier = Modifier.weight(1f))
                val allDownloaded = chapters.isNotEmpty() && chapters.all { downloads[it.id] == 2 }
                val anyDownloading = chapters.any { downloads[it.id] == 1 }
                when {
                    offline -> Unit                       // downloading needs the server
                    anyDownloading -> Text("⚙ Downloading…", color = Theme.brass, fontSize = 12.sp)
                    allDownloaded -> TextButton(onClick = { removeAll() }) {
                        Text("✕ Remove all", color = Theme.parchmentDim, fontSize = 12.sp)
                    }
                    else -> TextButton(onClick = { downloadAll() }) {
                        Text("⬇ All", color = Theme.verdigris, fontSize = 12.sp)
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            chapters.forEachIndexed { idx, ch ->
                // Offline: only the chapters actually on disk are listed — the rest can't play.
                if (offline && !Downloads.isDownloaded(context, ch.id)) return@forEachIndexed
                val pr = progresses.getOrElse(idx) { ChapterProgress() }
                val isCurrent = ch.id == current?.id
                Box {
                    Row(
                        Modifier.fillMaxWidth()
                            .padding(vertical = 3.dp)
                            .then(if (isCurrent)
                                Modifier.electricPanel(Theme.surface2, corner = 4.dp, alpha = 0.8f, elevation = 8.dp)
                            else Modifier.charged())   // every chapter row stays a little charged
                            .combinedClickable(
                                onClick = { loadChapter(ch, progresses[idx].positionSeconds) },
                                onLongClick = {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    menuChapterId = ch.id
                                })
                            .padding(horizontal = 12.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("${ch.trackNumber}", color = Theme.parchmentDim, fontSize = 12.sp,
                            modifier = Modifier.width(28.dp))
                        Text(ch.title, color = if (pr.isListened) Theme.parchmentDim else Theme.parchment,
                            fontSize = 14.sp,
                            textDecoration = if (pr.isListened) TextDecoration.LineThrough else null,
                            modifier = Modifier.weight(1f).padding(end = 8.dp))
                        // Always-visible status: ✓ finished, ◐ in progress, ○ not started.
                        Text(
                            text = when {
                                pr.isListened -> "✓"
                                pr.positionSeconds > 0 -> "◐"
                                else -> "○"
                            },
                            color = when {
                                pr.isListened -> Theme.verdigris
                                pr.positionSeconds > 0 -> Theme.brass
                                else -> Theme.parchmentDim.copy(alpha = 0.5f)
                            },
                            fontSize = 18.sp,
                            style = if (pr.isListened)
                                androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris)
                            else androidx.compose.ui.text.TextStyle()
                        )
                        // Offline-download indicator.
                        when (downloads[ch.id]) {
                            1 -> Text("  ⏳", color = Theme.brass, fontSize = 13.sp)
                            2 -> Text("  ⬇", color = Theme.verdigris, fontSize = 14.sp,
                                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
                        }
                        if (isCurrent) Text("  ▶", color = Theme.brassPale, fontSize = 16.sp)
                    }
                    DropdownMenu(expanded = menuChapterId == ch.id,
                        onDismissRequest = { menuChapterId = null },
                        containerColor = Theme.surface2,
                        border = androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris),
                        modifier = Modifier.background(Theme.surface2)) {
                        // Everything but download management needs the server.
                        if (!offline) {
                        DropdownMenuItem(
                            text = {
                                Text("↺ Reset chapter", color = Theme.parchment,
                                    fontFamily = Theme.body, fontSize = 15.sp)
                            },
                            onClick = {
                                menuChapterId = null
                                scope.launch {
                                    api.resetChapter(ch.id)
                                    progresses = progresses.toMutableList().also { it[idx] = ChapterProgress() }
                                }
                            })
                        DropdownMenuItem(
                            text = {
                                Text("✓ Mark completed", color = Theme.parchment,
                                    fontFamily = Theme.body, fontSize = 15.sp)
                            },
                            onClick = {
                                menuChapterId = null
                                scope.launch {
                                    api.completeChapter(ch.id)
                                    progresses = progresses.toMutableList().also {
                                        it[idx] = it[idx].copy(isListened = true)
                                    }
                                }
                            })
                        DropdownMenuItem(
                            text = {
                                Text("✎ Edit chapter", color = Theme.parchment,
                                    fontFamily = Theme.body, fontSize = 15.sp)
                            },
                            onClick = {
                                menuChapterId = null
                                editChapter = ch
                            })
                        }
                        if (downloads[ch.id] == 2) {
                            DropdownMenuItem(
                                text = {
                                    Text("⬇ Remove download", color = Theme.parchment,
                                        fontFamily = Theme.body, fontSize = 15.sp)
                                },
                                onClick = { menuChapterId = null; removeDownload(ch) })
                        } else if (downloads[ch.id] != 1) {
                            DropdownMenuItem(
                                text = {
                                    Text("⬇ Download for offline", color = Theme.parchment,
                                        fontFamily = Theme.body, fontSize = 15.sp)
                                },
                                onClick = { menuChapterId = null; downloadChapter(ch) })
                        }
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
            if (!offline) {
                TextButton(onClick = {
                    scope.launch {
                        api.resetBook(bookId)
                        progresses = progresses.map { ChapterProgress() }
                    }
                }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Text("⚙ Reset All Progress", color = Theme.parchmentDim, fontSize = 12.sp)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showInfo && book != null) {
        BookInfoDialog(api, book!!, onDismiss = { showInfo = false })
    }
    if (showMeta && book != null) {
        MetaEditorDialog(api, book!!, onDismiss = { showMeta = false },
            onSaved = { scope.launch { book = api.getBook(bookId); invalidateCover(bookId); showMeta = false } })
    }

    editChapter?.let { ch ->
        ChapterEditorDialog(api, ch, onDismiss = { editChapter = null },
            onSaved = { newTitle, newTrack ->
                chapters = chapters.map {
                    if (it.id == ch.id) it.copy(title = newTitle, trackNumber = newTrack) else it
                }
                editChapter = null
            })
    }
}

@Composable
@OptIn(ExperimentalFoundationApi::class)
private fun AudioPlayerBar(audio: AudioController, auth: AuthStore) {
    var showSpeed by remember { mutableStateOf(false) }
    val speeds = listOf(0.75, 1.0, 1.25, 1.5, 2.0)
    val haptic = LocalHapticFeedback.current
    // Pulsing green-electric glow, livelier while playing.
    val pulse = rememberInfiniteTransition(label = "glow")
    val glow by pulse.animateFloat(
        initialValue = 0.45f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(if (audio.isPlaying) 650 else 1600), RepeatMode.Reverse),
        label = "glowAlpha")
    // Time phase (seconds), always advancing — drives the orb's elaborate pulse ripples
    // (they keep rippling, slower, even when paused).
    var phase by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        var last = withFrameNanos { it }
        while (true) {
            val now = withFrameNanos { it }
            phase += (now - last) / 1_000_000_000f
            last = now
        }
    }

    Column(
        Modifier.fillMaxWidth()
            .electricPanel(Theme.surface, corner = 6.dp, alpha = 0.7f, elevation = 18.dp)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Text(audio.title, color = Theme.parchment, fontSize = 14.sp, maxLines = 1,
                modifier = Modifier.weight(1f))
            Text(if (audio.duration > 0)
                "${formatTime(audio.currentPosition)} / ${formatTime(audio.duration)}"
                 else formatTime(audio.currentPosition),
                color = Theme.parchmentDim, fontSize = 12.sp)
            if (audio.castSupported) {
                AndroidView(
                    modifier = Modifier.size(40.dp),
                    factory = { ctx ->
                        // MediaRouteButton needs an AppCompat theme; wrap + guard so a
                        // failure can never crash the player screen.
                        runCatching {
                            val themed = android.view.ContextThemeWrapper(
                                ctx, androidx.appcompat.R.style.Theme_AppCompat_DayNight_NoActionBar)
                            androidx.mediarouter.app.MediaRouteButton(themed).apply {
                                com.google.android.gms.cast.framework.CastButtonFactory
                                    .setUpMediaRouteButton(themed, this)
                            }
                        }.getOrElse { android.view.View(ctx) }
                    })
            }
        }
        // Source badge: casting / local file / streaming.
        val (badge, badgeColor) = when {
            audio.casting -> "📡 Casting" to Theme.verdigris
            audio.isLocal -> "📱 Local" to Theme.verdigris
            else -> "📡 Streaming" to Theme.brass
        }
        Text(badge, color = badgeColor, fontSize = 11.sp,
            style = if (audio.casting || audio.isLocal)
                androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris)
            else androidx.compose.ui.text.TextStyle())
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { audio.skipBack() }) {
                Text("⏮30", color = Theme.brass, fontSize = 20.sp)
            }
            // Electric orb play/pause — tap to play/pause, long-press for playback options.
            Box(
                Modifier.size(112.dp)
                    .shadow(28.dp, CircleShape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
                    .combinedClickable(
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            audio.togglePlay()
                        },
                        onLongClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            showSpeed = true
                        }),
                contentAlignment = Alignment.Center
            ) {
                Canvas(Modifier.matchParentSize()) { drawElectricButton(glow, audio.isPlaying) }
                // Elaborate pulse: ripples radiating past the rim — larger, unclipped canvas.
                Canvas(Modifier.size(240.dp)) { drawPulses(phase, glow, audio.isPlaying) }
                Icon(
                    imageVector = if (audio.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                    contentDescription = if (audio.isPlaying) "Pause" else "Play",
                    tint = Theme.brassPale,
                    modifier = Modifier.size(50.dp))
            }
            TextButton(onClick = { audio.skipForward() }) {
                Text("30⏭", color = Theme.brass, fontSize = 20.sp)
            }
        }
        if (audio.duration > 0) {
            Slider(value = audio.currentPosition.toFloat(),
                onValueChange = { audio.seek(it.toDouble()) },
                valueRange = 0f..audio.duration.toFloat(),
                colors = SliderDefaults.colors(thumbColor = Theme.brass, activeTrackColor = Theme.brass))
        }
    }

    if (showSpeed) {
        AlertDialog(onDismissRequest = { showSpeed = false },
            confirmButton = {},
            containerColor = Theme.surface,
            title = { Text("Playback", color = Theme.brass, fontFamily = Theme.serif) },
            text = {
                Column {
                    Text("Speed", color = Theme.parchmentDim, fontSize = 12.sp)
                    speeds.forEach { s ->
                        val selected = kotlin.math.abs(audio.speed - s) < 0.01
                        TextButton(onClick = { audio.setRate(s); showSpeed = false },
                            modifier = Modifier.fillMaxWidth()) {
                            Text("${if (s % 1.0 == 0.0) s.toInt().toString() else s}×",
                                color = if (selected) Theme.brassPale else Theme.parchmentMid,
                                fontSize = 18.sp,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                style = if (selected)
                                    androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris)
                                else androidx.compose.ui.text.TextStyle())
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(
                        Modifier.fillMaxWidth()
                            .clip(RoundedCornerShape(4.dp))
                            .clickable { auth.setAutoplay(!auth.autoplayNext) }
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = auth.autoplayNext,
                            onCheckedChange = { auth.setAutoplay(it) },
                            colors = CheckboxDefaults.colors(
                                checkedColor = Theme.verdigris,
                                uncheckedColor = Theme.parchmentDim,
                                checkmarkColor = Theme.ink))
                        Text("Autoplay next chapter", color = Theme.parchment, fontSize = 14.sp)
                    }
                    Row(
                        Modifier.fillMaxWidth()
                            .clip(RoundedCornerShape(4.dp))
                            .clickable { auth.setVolumeBoost(!auth.volumeBoosted); audio.setBoost(auth.volumeBoosted) }
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = auth.volumeBoosted,
                            onCheckedChange = { auth.setVolumeBoost(it); audio.setBoost(it) },
                            colors = CheckboxDefaults.colors(
                                checkedColor = Theme.verdigris,
                                uncheckedColor = Theme.parchmentDim,
                                checkmarkColor = Theme.ink))
                        Text("Volume boost", color = Theme.parchment, fontSize = 14.sp)
                    }
                }
            })
    }
}

// A dark orb with a breathing core, concentric in-place rings, and a glowing rim.
private fun DrawScope.drawElectricButton(glow: Float, playing: Boolean) {
    val cx = size.width / 2f
    val cy = size.height / 2f
    val outer = size.minDimension / 2f
    val r = outer * 0.82f
    val center = Offset(cx, cy)

    // Dark orb base with a faint electric-blue depth.
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(Color(0xFF0A2A40), Theme.ink),
            center = center, radius = r * 1.15f),
        radius = r, center = center)

    // Breathing core glow (hotter while playing).
    val coreA = (if (playing) 0.55f else 0.22f) * (0.55f + 0.45f * glow)
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(Theme.verdigris.copy(alpha = coreA), Theme.verdigris.copy(alpha = 0f)),
            center = center, radius = r * 0.92f),
        radius = r * 0.92f, center = center)

    // Concentric inner rings that breathe in place.
    for (i in 1..3) {
        drawCircle(color = Theme.verdigris.copy(alpha = (0.10f + 0.24f * glow) / i),
            radius = r * (0.30f * i), center = center, style = Stroke(width = 2f))
    }

    // Breathing rim — outer halo + crisp ring.
    drawCircle(color = Theme.verdigris.copy(alpha = 0.18f * glow),
        radius = r + outer * 0.08f, center = center, style = Stroke(width = outer * 0.05f))
    drawCircle(color = Theme.verdigris.copy(alpha = if (playing) glow else glow * 0.6f),
        radius = r, center = center, style = Stroke(width = outer * 0.05f * glow + 2f))
}

// Elaborate pulse — staggered concentric ripples expanding from the rim and fading,
// plus a breathing source ring. Faster while playing. Mirrors iOS drawPulses.
private fun DrawScope.drawPulses(phase: Float, glow: Float, playing: Boolean) {
    val cx = size.width / 2f; val cy = size.height / 2f
    val center = Offset(cx, cy)
    val rimR = minOf(size.width, size.height) * 0.195f
    val expand = size.width * 0.26f
    val period = if (playing) 1.6f else 3.2f
    val count = 4
    val plus = androidx.compose.ui.graphics.BlendMode.Plus
    for (k in 0 until count) {
        val p = ((phase / period) + k / count.toFloat()) % 1f
        val rr = rimR + p * expand
        val a = (1f - p) * (if (playing) 1.0f else 0.5f)
        if (a < 0.02f) continue
        drawCircle(Theme.verdigris.copy(alpha = 0.30f * a), radius = rr, center = center,
            style = Stroke(width = 7f * (1f - p) + 2f), blendMode = plus)
        drawCircle(Color(0xFFC8F0FF).copy(alpha = 0.7f * a), radius = rr, center = center,
            style = Stroke(width = 2f), blendMode = plus)
    }
    // Breathing source ring at the rim.
    drawCircle(Theme.verdigris.copy(alpha = 0.5f * glow), radius = rimR, center = center,
        style = Stroke(width = 3f))
}

// Full book info: cover + all metadata + untruncated description.
@Composable
private fun BookInfoDialog(api: ApiClient, book: Book, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Theme.surface,
        titleContentColor = Theme.brass,
        textContentColor = Theme.parchment,
        title = { Text(book.title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.Top) {
                    CoverImage(book, api, Modifier.size(96.dp).clip(RoundedCornerShape(4.dp)))
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(book.author, color = Theme.parchmentMid, fontSize = 14.sp)
                        book.narrator?.let {
                            Text("Narrated by $it", color = Theme.parchmentDim, fontSize = 13.sp)
                        }
                        book.year?.let {
                            Text(it.toString(), color = Theme.parchmentDim, fontSize = 13.sp)
                        }
                    }
                }
                book.description?.takeIf { it.isNotBlank() }?.let {
                    Text(it, color = Theme.parchment, fontSize = 14.sp, fontFamily = Theme.serif,
                        lineHeight = 20.sp)
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done", color = Theme.brass) } }
    )
}

@Composable
private fun MetaEditorDialog(api: ApiClient, book: Book, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var title by remember { mutableStateOf(book.title) }
    var author by remember { mutableStateOf(book.author) }
    var narrator by remember { mutableStateOf(book.narrator ?: "") }
    var year by remember { mutableStateOf(book.year?.toString() ?: "") }
    var description by remember { mutableStateOf(book.description ?: "") }
    var saving by remember { mutableStateOf(false) }
    var coverBytes by remember { mutableStateOf<ByteArray?>(null) }

    LaunchedEffect(book.id) {
        api.getBookMeta(book.id)?.let {
            title = it.title; author = it.author; narrator = it.narrator ?: ""; year = it.year?.toString() ?: ""
            description = it.description ?: ""
        }
    }

    var coverMime by remember { mutableStateOf("image/jpeg") }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            coverBytes = context.contentResolver.openInputStream(it)?.use { s -> s.readBytes() }
            coverMime = context.contentResolver.getType(it) ?: "image/jpeg"
        }
    }

    fun pasteCover() {
        val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE)
            as? android.content.ClipboardManager
        val uri = clipboard?.primaryClip?.getItemAt(0)?.uri
        val mime = uri?.let { context.contentResolver.getType(it) }
        if (uri == null || mime?.startsWith("image/") != true) {
            android.widget.Toast.makeText(context, "No image on the clipboard",
                android.widget.Toast.LENGTH_SHORT).show()
            return
        }
        coverBytes = context.contentResolver.openInputStream(uri)?.use { s -> s.readBytes() }
        coverMime = mime
    }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedTextColor = Theme.parchment,
        unfocusedTextColor = Theme.parchment,
        cursorColor = Theme.brass,
        focusedBorderColor = Theme.brass,
        unfocusedBorderColor = Theme.parchmentDim,
        focusedLabelColor = Theme.brass,
        unfocusedLabelColor = Theme.parchmentDim,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Theme.surface,
        titleContentColor = Theme.brass,
        textContentColor = Theme.parchment,
        title = { Text("Edit Details") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true, colors = fieldColors)
                OutlinedTextField(author, { author = it }, label = { Text("Author") }, singleLine = true, colors = fieldColors)
                OutlinedTextField(narrator, { narrator = it }, label = { Text("Narrator") }, singleLine = true, colors = fieldColors)
                OutlinedTextField(year, { year = it }, label = { Text("Year") }, singleLine = true, colors = fieldColors)
                OutlinedTextField(description, { description = it }, label = { Text("Description") },
                    minLines = 3, maxLines = 8, colors = fieldColors)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { picker.launch("image/*") }) {
                        Text(if (coverBytes == null) "Choose Cover Image" else "📎 Cover selected", color = Theme.brass)
                    }
                    TextButton(onClick = { pasteCover() }) {
                        Text("📋 Paste", color = Theme.brass)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(enabled = !saving, onClick = {
                saving = true
                scope.launch {
                    api.saveBookMeta(book.id, title, author, narrator.ifBlank { null },
                        description.ifBlank { null }, year.toIntOrNull())
                    coverBytes?.let { api.uploadCover(book.id, it, coverMime) }
                    saving = false
                    onSaved()
                }
            }) { Text(if (saving) "Saving…" else "Save", color = Theme.brass) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Theme.parchmentDim) } }
    )
}

@Composable
private fun ChapterEditorDialog(
    api: ApiClient, chapter: Chapter,
    onDismiss: () -> Unit, onSaved: (String, Int) -> Unit
) {
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf(chapter.title) }
    var track by remember { mutableStateOf(chapter.trackNumber.toString()) }
    var saving by remember { mutableStateOf(false) }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        focusedTextColor = Theme.parchment,
        unfocusedTextColor = Theme.parchment,
        cursorColor = Theme.brass,
        focusedBorderColor = Theme.brass,
        unfocusedBorderColor = Theme.parchmentDim,
        focusedLabelColor = Theme.brass,
        unfocusedLabelColor = Theme.parchmentDim,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Theme.surface,
        titleContentColor = Theme.brass,
        textContentColor = Theme.parchment,
        title = { Text("Edit Chapter") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(title, { title = it }, label = { Text("Title") },
                    singleLine = true, colors = fieldColors)
                OutlinedTextField(track, { track = it.filter(Char::isDigit) },
                    label = { Text("Track #") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = fieldColors)
            }
        },
        confirmButton = {
            TextButton(enabled = !saving, onClick = {
                saving = true
                val newTrack = track.toIntOrNull() ?: chapter.trackNumber
                scope.launch {
                    api.updateChapter(chapter.id, title, newTrack)
                    saving = false
                    onSaved(title, newTrack)
                }
            }) { Text(if (saving) "Saving…" else "Save", color = Theme.brass) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = Theme.parchmentDim) } }
    )
}
