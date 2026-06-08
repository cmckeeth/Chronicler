package app.chronicler

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.launch

@Composable
fun BookPlayerScreen(auth: AuthStore, nav: NavController, bookId: Int) {
    val context = LocalContext.current
    val api = auth.api
    val scope = rememberCoroutineScope()
    val audio = remember { AudioController(context) }

    var book by remember { mutableStateOf<Book?>(null) }
    var chapters by remember { mutableStateOf<List<Chapter>>(emptyList()) }
    var progresses by remember { mutableStateOf<List<ChapterProgress>>(emptyList()) }
    var current by remember { mutableStateOf<Chapter?>(null) }
    var showMeta by remember { mutableStateOf(false) }

    fun loadChapter(ch: Chapter, start: Double) {
        current = ch
        audio.load(api.audioUrl(ch.id), ch.title, start, api.token)
    }

    LaunchedEffect(bookId) {
        audio.onProgress = { pos ->
            scope.launch {
                current?.let { cur ->
                    api.saveChapterProgress(cur.id, pos, 0.0)
                    val idx = chapters.indexOfFirst { it.id == cur.id }
                    if (idx >= 0) progresses = progresses.toMutableList()
                        .also { it[idx] = it[idx].copy(positionSeconds = pos) }
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
        progresses = chapters.map { api.getChapterProgress(it.id) }
        if (chapters.isNotEmpty()) {
            var idx = progresses.indexOfFirst { !it.isListened && it.positionSeconds > 0 }
            if (idx < 0) idx = progresses.indexOfFirst { !it.isListened }
            if (idx < 0) idx = 0
            loadChapter(chapters[idx], progresses[idx].positionSeconds)
        }
    }

    DisposableEffect(Unit) { onDispose { audio.release() } }

    Column(Modifier.fillMaxSize().background(Theme.bg).verticalScroll(rememberScrollState()).padding(12.dp)) {
        TextButton(onClick = { nav.popBackStack() }) {
            Text("‹ Library", color = Theme.brass)
        }
        val b = book
        if (b == null) {
            Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                Text("Consulting the archive...", color = Theme.parchmentDim)
            }
        } else {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                CoverImage(b, api, Modifier.size(120.dp).clip(RoundedCornerShape(4.dp))
                    .clickable { scope.launch { showMeta = true } })
                Text(b.title, color = Theme.parchment, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Row {
                    Text(b.author, color = Theme.parchmentMid, fontSize = 14.sp)
                    b.narrator?.let { Text(" · $it", color = Theme.parchmentDim, fontSize = 14.sp) }
                }
            }

            Spacer(Modifier.height(12.dp))
            if (current != null) AudioPlayerBar(audio)

            Spacer(Modifier.height(12.dp))
            Text("Chapters", color = Theme.brass, fontSize = 16.sp)
            chapters.forEachIndexed { idx, ch ->
                val pr = progresses.getOrElse(idx) { ChapterProgress() }
                val isCurrent = ch.id == current?.id
                Row(
                    Modifier.fillMaxWidth()
                        .background(if (isCurrent) Theme.surface2 else Color.Transparent, RoundedCornerShape(3.dp))
                        .clickable { loadChapter(ch, progresses[idx].positionSeconds) }
                        .padding(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("${ch.trackNumber}", color = Theme.parchmentDim, fontSize = 12.sp,
                        modifier = Modifier.width(24.dp))
                    Text(ch.title, color = if (pr.isListened) Theme.parchmentDim else Theme.parchment,
                        fontSize = 14.sp,
                        textDecoration = if (pr.isListened) TextDecoration.LineThrough else null,
                        modifier = Modifier.weight(1f))
                    when {
                        pr.isListened -> Text("✓", color = Theme.verdigris)
                        pr.positionSeconds > 0 -> Text("…", color = Theme.brass)
                    }
                    if (isCurrent) Text(" ▶", color = Theme.brassPale)
                    TextButton(onClick = {
                        scope.launch {
                            api.resetChapter(ch.id)
                            progresses = progresses.toMutableList().also { it[idx] = ChapterProgress() }
                        }
                    }) { Text("↺", color = Theme.parchmentDim) }
                }
            }

            Spacer(Modifier.height(8.dp))
            TextButton(onClick = {
                scope.launch {
                    api.resetBook(bookId)
                    progresses = progresses.map { ChapterProgress() }
                }
            }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text("⚙ Reset All Progress", color = Theme.parchmentDim, fontSize = 12.sp)
            }
        }
    }

    if (showMeta && book != null) {
        MetaEditorDialog(api, book!!, onDismiss = { showMeta = false },
            onSaved = { scope.launch { book = api.getBook(bookId); invalidateCover(bookId); showMeta = false } })
    }
}

@Composable
private fun AudioPlayerBar(audio: AudioController) {
    var showSpeed by remember { mutableStateOf(false) }
    val speeds = listOf(0.75, 1.0, 1.25, 1.5, 2.0)

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
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(20.dp),
            verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { audio.skipBack() }) { Text("⏮30", color = Theme.brass) }
            TextButton(onClick = { audio.togglePlay() }) {
                Text(if (audio.isPlaying) "⏸" else "▶", color = Theme.brass, fontSize = 28.sp)
            }
            TextButton(onClick = { audio.skipForward() }) { Text("30⏭", color = Theme.brass) }
            TextButton(onClick = { showSpeed = true }) {
                Text("${if (audio.speed % 1.0 == 0.0) audio.speed.toInt().toString() else audio.speed}×",
                    color = Theme.parchmentMid)
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
            title = { Text("Speed") },
            text = {
                Column {
                    speeds.forEach { s ->
                        TextButton(onClick = { audio.setRate(s); showSpeed = false }) {
                            Text("${if (s % 1.0 == 0.0) s.toInt().toString() else s}×")
                        }
                    }
                }
            })
    }
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
