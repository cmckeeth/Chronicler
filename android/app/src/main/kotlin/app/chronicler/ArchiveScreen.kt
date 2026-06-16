package app.chronicler

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.launch

@Composable
fun ArchiveScreen(auth: AuthStore, nav: NavController) {
    var books by remember { mutableStateOf<List<Book>>(emptyList()) }
    var search by remember { mutableStateOf("") }
    var sort by remember { mutableStateOf("name") }
    var filter by remember { mutableStateOf("favorites") }
    var loading by remember { mutableStateOf(true) }
    var refreshing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    suspend fun load() {
        loading = true; error = null
        runCatching { auth.api.getBooks() }
            .onSuccess { books = it }
            .onFailure { error = "unreachable" }
        loading = false
    }

    // Reload without blanking the grid — keeps current books visible while fetching.
    suspend fun refresh() {
        refreshing = true
        runCatching { auth.api.getBooks() }
            .onSuccess { books = it; error = null }
            .onFailure { error = "unreachable" }
        refreshing = false
    }
    LaunchedEffect(Unit) { load() }

    val filtered = remember(books, search, sort, filter) {
        var q = books
        if (search.isNotBlank()) {
            val s = search.lowercase()
            q = q.filter {
                it.title.lowercase().contains(s) || it.author.lowercase().contains(s) ||
                    (it.narrator?.lowercase()?.contains(s) ?: false)
            }
        }
        q = when (filter) {
            "inprogress" -> q.filter { it.isInProgress }
            "favorites" -> q.filter { it.isFavorite }
            else -> q
        }
        when (sort) {
            "date" -> q.sortedByDescending { it.addedAt }
            "progress" -> q.sortedWith(
                compareByDescending<Book> { it.isInProgress }
                    .thenByDescending { it.isCompleted }.thenBy { it.title })
            else -> q.sortedBy { it.title.lowercase() }
        }
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 14.dp)) {
        Text("The Archive", color = Theme.brass, fontSize = 24.sp, fontWeight = FontWeight.Bold,
            fontFamily = Theme.serif, letterSpacing = 2.sp,
            style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
            modifier = Modifier.align(Alignment.CenterHorizontally).padding(vertical = 6.dp))
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(value = search, onValueChange = { search = it },
            placeholder = { Text("Query the archive...", color = Theme.parchmentDim) },
            singleLine = true, modifier = Modifier.fillMaxWidth(),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Theme.parchment, unfocusedTextColor = Theme.parchment,
                focusedContainerColor = Theme.surface2, unfocusedContainerColor = Theme.surface2,
                focusedBorderColor = Theme.verdigris,
                unfocusedBorderColor = Theme.verdigris.copy(alpha = 0.4f),
                cursorColor = Theme.verdigris))
        Spacer(Modifier.height(14.dp))
        chipRow("Sort", listOf("Name" to "name", "Added" to "date", "Progress" to "progress"),
            sort) { sort = it }
        Spacer(Modifier.height(10.dp))
        chipRow("Show", listOf("All" to "all", "In Progress" to "inprogress", "★ Favorites" to "favorites"),
            filter) { filter = it }
        Spacer(Modifier.height(18.dp))

        when {
            loading -> center("Consulting the archive...", Theme.parchmentDim)
            error != null -> center("The pneumatic tubes have failed: $error", Theme.rust)
            filtered.isEmpty() -> center(
                if (books.isEmpty()) "The archive lies empty, traveller." else "No volumes match this filter.",
                Theme.parchmentDim)
            else -> LazyVerticalGrid(columns = GridCells.Adaptive(150.dp),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
                contentPadding = PaddingValues(vertical = 4.dp)) {
                items(filtered, key = { it.id }) { book ->
                    BookCard(book, auth.api, onOpen = { nav.navigate("book/${book.id}") },
                        onToggleFavorite = { scope.launch { auth.api.toggleFavorite(book.id); load() } })
                }
            }
        }

        Spacer(Modifier.height(10.dp))
        Surface(color = Theme.brass, shape = RoundedCornerShape(50),
            border = androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris),
            modifier = Modifier
                .fillMaxWidth()
                .shadow(8.dp, RoundedCornerShape(50),
                    spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
                .clickable(enabled = !refreshing) { scope.launch { refresh() } }) {
            Row(verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)) {
                if (refreshing) {
                    CircularProgressIndicator(color = Theme.ink, strokeWidth = 2.dp,
                        modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Consulting the archive...", color = Theme.ink, fontSize = 13.sp)
                } else {
                    Text("↻", color = Theme.ink, fontSize = 16.sp, fontFamily = Theme.serif)
                    Spacer(Modifier.width(8.dp))
                    Text("Refresh the Archive", color = Theme.ink, fontSize = 13.sp)
                }
            }
        }

        UpdateBanner(auth.api, Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp))
    }
}

@Composable
private fun ColumnScope.center(text: String, color: Color) {
    Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
        Text(text, color = color, fontSize = 15.sp)
    }
}

@Composable
private fun chipRow(label: String, options: List<Pair<String, String>>, selected: String,
                    onSelect: (String) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, color = Theme.parchmentDim, fontSize = 11.sp)
        options.forEach { (title, value) ->
            val active = selected == value
            Surface(color = if (active) Theme.brass else Theme.surface2,
                shape = RoundedCornerShape(50),
                border = if (active) androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris) else null,
                modifier = Modifier
                    .then(if (active) Modifier.shadow(8.dp, RoundedCornerShape(50),
                        spotColor = Theme.verdigris, ambientColor = Theme.verdigris) else Modifier)
                    .combinedClickableSafe { onSelect(value) }) {
                Text(title, color = if (active) Theme.ink else Theme.parchmentMid, fontSize = 12.sp,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp))
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BookCard(book: Book, api: ApiClient, onOpen: () -> Unit, onToggleFavorite: () -> Unit) {
    Column(
        Modifier
            .combinedClickable(onClick = onOpen, onLongClick = onToggleFavorite)
            .electricPanel(Theme.surface, corner = 4.dp,
                alpha = if (book.isFavorite) 0.9f else 0.5f,
                elevation = if (book.isFavorite) 18.dp else 10.dp)
            .padding(10.dp)
    ) {
        Box {
            CoverImage(book, api, Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(2.dp)))
            if (book.isFavorite) {
                Text("★", color = Theme.brassPale, fontSize = 18.sp,
                    modifier = Modifier.align(Alignment.TopEnd).padding(6.dp))
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(book.title, color = Theme.parchment, fontSize = 14.sp, maxLines = 2)
        Spacer(Modifier.height(3.dp))
        Text(book.author, color = Theme.parchmentDim, fontSize = 12.sp, maxLines = 1)
        book.narrator?.let {
            Spacer(Modifier.height(2.dp))
            Text(it, color = Theme.parchmentDim, fontSize = 11.sp, maxLines = 1)
        }
        Spacer(Modifier.height(2.dp))
    }
}

// Small helper so chips get a clickable without importing the experimental API everywhere.
private fun Modifier.combinedClickableSafe(onClick: () -> Unit): Modifier =
    this.clickable(onClick = onClick)
