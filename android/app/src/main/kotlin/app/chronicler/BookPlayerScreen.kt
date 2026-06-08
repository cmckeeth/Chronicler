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
import androidx.compose.ui.text.font.FontWeight
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
    var menuChapterId by remember { mutableStateOf<Int?>(null) }

    fun loadChapter(ch: Chapter, start: Double) {
        current = ch
        audio.load(api.audioUrl(ch.id), ch.title, start, api.token)
    }

    LaunchedEffect(bookId) {
        audio.onProgress = { pos ->
            scope.launch {
                current?.let { cur ->
                    val dur = audio.duration
                    api.saveChapterProgress(cur.id, pos, dur)        // send real duration so server marks finished
                    val idx = chapters.indexOfFirst { it.id == cur.id }
                    if (idx >= 0) {
                        val finished = dur > 0 && pos / dur >= 0.95   // 95% = finished
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
            if (idx in 0 until chapters.size - 1) {
                progresses = progresses.toMutableList().also { it[idx] = it[idx].copy(isListened = true) }
                loadChapter(chapters[idx + 1], 0.0)
            }
        }

        book = api.getBook(bookId) ?: return@LaunchedEffect
        chapters = api.getChapters(bookId)
        // Load all chapter statuses in parallel so they show immediately on open.
        progresses = coroutineScope {
            chapters.map { ch -> async { api.getChapterProgress(ch.id) } }.awaitAll()
        }
        if (chapters.isNotEmpty()) {
            // Resume at the latest chapter that isn't completed:
            //  1) the furthest-along chapter that's started but unfinished,
            //  2) else the chapter right after the last finished one,
            //  3) else the first unfinished chapter, 4) else the first.
            val lastInProgress = progresses.indexOfLast { !it.isListened && it.positionSeconds > 0 }
            val lastListened = progresses.indexOfLast { it.isListened }
            var idx = when {
                lastInProgress >= 0 -> lastInProgress
                lastListened in 0 until chapters.size - 1 -> lastListened + 1
                else -> progresses.indexOfFirst { !it.isListened }
            }
            if (idx < 0) idx = 0
            loadChapter(chapters[idx], progresses[idx].positionSeconds)
        }
    }

    DisposableEffect(Unit) { onDispose { audio.release() } }

    Column(Modifier.fillMaxSize().background(Theme.bg).verticalScroll(rememberScrollState())
        .padding(horizontal = 20.dp, vertical = 12.dp)) {
        TextButton(onClick = { nav.popBackStack() }, contentPadding = PaddingValues(0.dp)) {
            Text("‹ Library", color = Theme.brass)
        }
        Spacer(Modifier.height(8.dp))
        val b = book
        if (b == null) {
            Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                Text("Consulting the archive...", color = Theme.parchmentDim)
            }
        } else {
            Column(Modifier.fillMaxWidth().padding(top = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally) {
                CoverImage(b, api, Modifier.size(132.dp).clip(RoundedCornerShape(4.dp))
                    .clickable { scope.launch { showMeta = true } })
                Spacer(Modifier.height(14.dp))
                Text(b.title, color = Theme.parchment, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                    fontFamily = Theme.display,
                    style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowBrass))
                Spacer(Modifier.height(6.dp))
                Row {
                    Text(b.author, color = Theme.parchmentMid, fontSize = 14.sp)
                    b.narrator?.let { Text(" · $it", color = Theme.parchmentDim, fontSize = 14.sp) }
                }
            }

            Spacer(Modifier.height(20.dp))
            if (current != null) AudioPlayerBar(audio)

            Spacer(Modifier.height(24.dp))
            Text("Chapters", color = Theme.brass, fontSize = 16.sp, fontFamily = Theme.serif,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowBrass))
            Spacer(Modifier.height(8.dp))
            chapters.forEachIndexed { idx, ch ->
                val pr = progresses.getOrElse(idx) { ChapterProgress() }
                val isCurrent = ch.id == current?.id
                Box {
                    Row(
                        Modifier.fillMaxWidth()
                            .padding(vertical = 3.dp)
                            .background(if (isCurrent) Theme.surface2 else Color.Transparent, RoundedCornerShape(4.dp))
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
                        if (isCurrent) Text("  ▶", color = Theme.brassPale, fontSize = 16.sp)
                    }
                    DropdownMenu(expanded = menuChapterId == ch.id,
                        onDismissRequest = { menuChapterId = null }) {
                        DropdownMenuItem(
                            text = { Text(if (pr.isListened) "↺ Reset chapter (finished)" else "↺ Reset chapter") },
                            onClick = {
                                menuChapterId = null
                                scope.launch {
                                    api.resetChapter(ch.id)
                                    progresses = progresses.toMutableList().also { it[idx] = ChapterProgress() }
                                }
                            })
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
            TextButton(onClick = {
                scope.launch {
                    api.resetBook(bookId)
                    progresses = progresses.map { ChapterProgress() }
                }
            }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text("⚙ Reset All Progress", color = Theme.parchmentDim, fontSize = 12.sp)
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showMeta && book != null) {
        MetaEditorDialog(api, book!!, onDismiss = { showMeta = false },
            onSaved = { scope.launch { book = api.getBook(bookId); invalidateCover(bookId); showMeta = false } })
    }
}

@Composable
@OptIn(ExperimentalFoundationApi::class)
private fun AudioPlayerBar(audio: AudioController) {
    var showSpeed by remember { mutableStateOf(false) }
    val speeds = listOf(0.75, 1.0, 1.25, 1.5, 2.0)
    val haptic = LocalHapticFeedback.current
    // Pulsing green-electric glow, livelier while playing.
    val pulse = rememberInfiniteTransition(label = "glow")
    val glow by pulse.animateFloat(
        initialValue = 0.45f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(if (audio.isPlaying) 650 else 1600), RepeatMode.Reverse),
        label = "glowAlpha")
    // Gear spins while playing, freezes (holds angle) when paused.
    var gearAngle by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(audio.isPlaying) {
        if (audio.isPlaying) {
            var last = withFrameNanos { it }
            while (true) {
                val now = withFrameNanos { it }
                gearAngle = (gearAngle + (now - last) / 1_000_000_000f * 40f) % 360f
                last = now
            }
        }
    }

    Column(
        Modifier.fillMaxWidth().background(Theme.surface, RoundedCornerShape(4.dp)).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(audio.title, color = Theme.parchment, fontSize = 14.sp, maxLines = 1,
                modifier = Modifier.weight(1f))
            Text(if (audio.duration > 0)
                "${formatTime(audio.currentPosition)} / ${formatTime(audio.duration)}"
                 else formatTime(audio.currentPosition),
                color = Theme.parchmentDim, fontSize = 12.sp)
        }
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { audio.skipBack() }) {
                Text("⏮30", color = Theme.brass, fontSize = 20.sp)
            }
            // Steampunk brass-gear play/pause — tap to play/pause, long-press to set speed.
            Box(
                Modifier.size(112.dp)
                    .shadow(24.dp, CircleShape, spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
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
                Canvas(Modifier.matchParentSize()) { drawGearButton(glow, gearAngle) }
                Icon(
                    imageVector = if (audio.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                    contentDescription = if (audio.isPlaying) "Pause" else "Play",
                    tint = Theme.ink,
                    modifier = Modifier.size(48.dp))
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
            title = { Text("Playback Speed", color = Theme.brass, fontFamily = Theme.serif) },
            text = {
                Column {
                    speeds.forEach { s ->
                        val selected = kotlin.math.abs(audio.speed - s) < 0.01
                        TextButton(onClick = { audio.setRate(s); showSpeed = false },
                            modifier = Modifier.fillMaxWidth()) {
                            Text("${if (s % 1.0 == 0.0) s.toInt().toString() else s}×",
                                color = if (selected) Theme.brassPale else Theme.parchmentMid,
                                fontSize = 18.sp,
                                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                                style = if (selected)
                                    androidx.compose.ui.text.TextStyle(shadow = Theme.glowBrass)
                                else androidx.compose.ui.text.TextStyle())
                        }
                    }
                }
            })
    }
}

// Draws a brass cog: teeth, radial metallic sheen, rivets, and a pulsing verdigris ring.
// `angle` spins the mechanical parts (teeth + rivets); the sheen and ring stay fixed.
private fun DrawScope.drawGearButton(glow: Float, angle: Float) {
    val cx = size.width / 2f
    val cy = size.height / 2f
    val outer = size.minDimension / 2f
    val rFace = outer * 0.74f
    val toothW = outer * 0.26f
    val toothH = outer * 0.24f
    val teeth = 10

    // Gear teeth around the rim (rotating).
    for (i in 0 until teeth) {
        rotate(angle + i * 360f / teeth, pivot = Offset(cx, cy)) {
            drawRoundRect(
                color = Theme.borderBrass,
                topLeft = Offset(cx - toothW / 2f, cy - outer + 1f),
                size = Size(toothW, toothH),
                cornerRadius = CornerRadius(2f, 2f))
        }
    }
    // Brass face with an off-center sheen (fixed light source).
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(Theme.brassPale, Theme.brass, Theme.borderBrass),
            center = Offset(cx - rFace * 0.3f, cy - rFace * 0.3f),
            radius = rFace * 1.5f),
        radius = rFace, center = Offset(cx, cy))
    // Rim line.
    drawCircle(color = Theme.ink.copy(alpha = 0.4f), radius = rFace, center = Offset(cx, cy),
        style = Stroke(width = outer * 0.04f))
    // Rivets (rotating with the gear).
    val rivetRing = rFace * 0.80f
    val angleRad = angle / 180f * Math.PI.toFloat()
    for (i in 0 until 8) {
        val a = (i / 8f) * 2f * Math.PI.toFloat() + angleRad
        drawCircle(color = Theme.ink.copy(alpha = 0.5f), radius = outer * 0.04f,
            center = Offset(cx + rivetRing * kotlin.math.cos(a), cy + rivetRing * kotlin.math.sin(a)))
    }
    // Pulsing verdigris electric ring (fixed).
    drawCircle(color = Theme.verdigris.copy(alpha = glow),
        radius = rFace + outer * 0.015f, center = Offset(cx, cy),
        style = Stroke(width = outer * 0.06f * glow + 1f))
}

@Composable
private fun MetaEditorDialog(api: ApiClient, book: Book, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var title by remember { mutableStateOf(book.title) }
    var author by remember { mutableStateOf(book.author) }
    var narrator by remember { mutableStateOf(book.narrator ?: "") }
    var year by remember { mutableStateOf(book.year?.toString() ?: "") }
    var saving by remember { mutableStateOf(false) }
    var coverBytes by remember { mutableStateOf<ByteArray?>(null) }

    LaunchedEffect(book.id) {
        api.getBookMeta(book.id)?.let {
            title = it.title; author = it.author; narrator = it.narrator ?: ""; year = it.year?.toString() ?: ""
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            coverBytes = context.contentResolver.openInputStream(it)?.use { s -> s.readBytes() }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit Details") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true)
                OutlinedTextField(author, { author = it }, label = { Text("Author") }, singleLine = true)
                OutlinedTextField(narrator, { narrator = it }, label = { Text("Narrator") }, singleLine = true)
                OutlinedTextField(year, { year = it }, label = { Text("Year") }, singleLine = true)
                TextButton(onClick = { picker.launch("image/*") }) {
                    Text(if (coverBytes == null) "Choose Cover Image" else "📎 Cover selected")
                }
            }
        },
        confirmButton = {
            TextButton(enabled = !saving, onClick = {
                saving = true
                scope.launch {
                    api.saveBookMeta(book.id, title, author, narrator.ifBlank { null }, year.toIntOrNull())
                    coverBytes?.let { api.uploadCover(book.id, it, "image/jpeg") }
                    saving = false
                    onSaved()
                }
            }) { Text(if (saving) "Saving…" else "Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}
