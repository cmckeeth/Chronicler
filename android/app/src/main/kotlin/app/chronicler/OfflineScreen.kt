package app.chronicler

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavController

// The books whose chapters live on this device. Everything here is read off disk, so it
// works with the server unreachable — the way in when the Archive can't load.
@Composable
fun OfflineScreen(auth: AuthStore, onBack: () -> Unit, onOpenBook: (Int) -> Unit) {
    val context = LocalContext.current
    var entries by remember { mutableStateOf(Downloads.downloadedBooks(context)) }
    var total by remember { mutableStateOf(0L) }

    androidx.compose.runtime.LaunchedEffect(Unit) {
        entries = Downloads.downloadedBooks(context)
        total = Downloads.totalSize(context)
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("‹ Back", color = Theme.brass, fontSize = 14.sp) }
        }
        Text("Local Downloads", color = Theme.brass, fontSize = 24.sp, fontFamily = Theme.serif,
            fontWeight = FontWeight.Bold,
            style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
            modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
            textAlign = TextAlign.Center)
        Text(
            if (entries.isEmpty()) "Nothing downloaded yet."
            else "${entries.size} book${if (entries.size == 1) "" else "s"} · ${formatSize(total)} — playable with no connection.",
            color = Theme.parchmentDim, fontSize = 12.sp,
            modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)

        Spacer(Modifier.height(12.dp))

        if (entries.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Open a book while connected and use ⬇ All to keep it on this device.",
                    color = Theme.parchmentDim, fontSize = 15.sp, fontFamily = Theme.serif,
                    textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(entries, key = { it.book.id }) { entry ->
                    OfflineRow(entry, auth, context,
                        onOpen = { onOpenBook(entry.book.id) },
                        onDelete = {
                            Downloads.purgeBook(context, entry.book.id)
                            entries = Downloads.downloadedBooks(context)
                        })
                }
            }
        }
    }
}

@Composable
private fun OfflineRow(entry: DownloadedBook, auth: AuthStore, context: android.content.Context,
                       onOpen: () -> Unit, onDelete: () -> Unit) {
    var confirmDelete by remember { mutableStateOf(false) }
    val onDisk = Downloads.downloadedCount(context, entry.book.id)

    Row(
        Modifier
            .fillMaxWidth()
            .clickable { onOpen() }
            .charged()
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        CoverImage(entry.book, auth.api,
            Modifier.size(64.dp).clip(RoundedCornerShape(4.dp)))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(entry.book.title, color = Theme.parchment, fontSize = 15.sp,
                fontWeight = FontWeight.Bold, maxLines = 2)
            Text(entry.book.author, color = Theme.parchmentMid, fontSize = 12.sp,
                fontFamily = Theme.serif, maxLines = 1)
            Text("$onDisk of ${entry.chapters.size} chapters · ${formatSize(Downloads.bookSize(context, entry.book.id))}",
                color = Theme.verdigris, fontSize = 11.sp)
        }
        TextButton(onClick = { if (confirmDelete) onDelete() else confirmDelete = true }) {
            Text(if (confirmDelete) "Sure?" else "✕", color = Theme.rust, fontSize = 13.sp)
        }
    }
}

private fun formatSize(bytes: Long): String {
    val mb = bytes / 1_048_576.0
    return when {
        mb >= 1024 -> String.format("%.1f GB", mb / 1024)
        mb >= 1 -> String.format("%.0f MB", mb)
        else -> String.format("%.0f KB", bytes / 1024.0)
    }
}

// A pill that leads to the offline library. Emphasised (and re-worded) when the server
// is unreachable, since that's when it matters.
@Composable
fun LocalDownloadsButton(serverDown: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier
            .clickable { onClick() }
            .background(if (serverDown) Theme.brass else Theme.surface2, RoundedCornerShape(50))
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text("📥", fontSize = 13.sp)
        Text(if (serverDown) "Server unreachable — Local Downloads" else "Local Downloads",
            color = if (serverDown) Theme.ink else Theme.parchmentMid, fontSize = 13.sp)
    }
}
