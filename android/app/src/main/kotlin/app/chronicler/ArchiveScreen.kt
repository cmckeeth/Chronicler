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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.launch

@Composable
fun ArchiveScreen(auth: AuthStore, nav: NavController) {
    // All books, flat (including those inside collections); each chip derives its view client-side.
    var allBooks by remember { mutableStateOf<List<Book>>(emptyList()) }
    var collections by remember { mutableStateOf<List<Collection>>(emptyList()) }
    var search by remember { mutableStateOf("") }
    var tab by remember { mutableStateOf("books") }
    var favOnly by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var refreshing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    suspend fun fetch() {
        runCatching {
            allBooks = auth.api.getBooks()
            collections = auth.api.collections()
        }.onSuccess { error = null }.onFailure { error = "unreachable" }
    }

    suspend fun load() {
        loading = true; error = null
        fetch()
        loading = false
    }

    // Reload without blanking the grid — keeps current content visible while fetching.
    suspend fun refresh() {
        refreshing = true
        fetch()
        refreshing = false
    }
    LaunchedEffect(Unit) { load() }

    val searching = search.isNotBlank()
    val filtered = remember(allBooks, search, tab, favOnly) {
        // Books tab shows every book flat (standalone + inside collections); Collections tab
        // shows no books. While searching, always query every book flat.
        var q = when {
            searching -> allBooks
            tab == "books" -> allBooks
            else -> emptyList()
        }
        if (searching) {
            val s = search.lowercase()
            q = q.filter {
                it.title.lowercase().contains(s) || it.author.lowercase().contains(s) ||
                    (it.narrator?.lowercase()?.contains(s) ?: false)
            }
        }
        if (favOnly && tab == "books") q = q.filter { it.isFavorite }
        q.sortedBy { it.title.lowercase() }
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
        chipRow("", listOf("Books" to "books", "Collections" to "collections"),
            tab) { tab = it }
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (tab == "books") favChip(favOnly) { favOnly = !favOnly }
            Spacer(Modifier.weight(1f))
            chipRow("Grid", listOf("1" to "1", "2" to "2", "3" to "3"),
                auth.gridColumns.toString()) { auth.setGridSize(it.toInt()) }
        }
        Spacer(Modifier.height(18.dp))

        // Collections appear only on the Collections tab (never while searching).
        val shownCollections = if (searching || tab == "books") emptyList() else collections
        when {
            loading -> center("Consulting the archive...", Theme.parchmentDim)
            error != null -> Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("The pneumatic tubes have failed: $error", color = Theme.rust,
                        fontSize = 14.sp, textAlign = TextAlign.Center)
                    // The archive is out of reach, but downloaded books still play.
                    if (Downloads.hasAny(LocalContext.current)) {
                        LocalDownloadsButton(serverDown = true) { nav.navigate("offline") }
                    }
                }
            }
            filtered.isEmpty() && shownCollections.isEmpty() -> center(
                if (searching) "No volumes match this filter."
                else if (allBooks.isEmpty() && collections.isEmpty()) "The archive lies empty, traveller."
                else "No volumes match this filter.",
                Theme.parchmentDim)
            else -> LazyVerticalGrid(columns = GridCells.Fixed(auth.gridColumns),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
                contentPadding = PaddingValues(vertical = 4.dp)) {
                items(shownCollections, key = { "collection-${it.id}" }) { collection ->
                    CollectionCard(collection, auth.api,
                        onOpen = { nav.navigate("collection/${collection.id}") })
                }
                items(filtered, key = { it.id }) { book ->
                    BookCard(book, auth.api, wide = auth.gridColumns == 1,
                        onOpen = { nav.navigate("book/${book.id}") },
                        onToggleFavorite = { scope.launch { auth.api.toggleFavorite(book.id); load() } })
                }
            }
        }

        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
            UpdateBanner(auth.api)
            Spacer(Modifier.weight(1f))
            Surface(color = Theme.brass, shape = RoundedCornerShape(50),
                border = androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris),
                modifier = Modifier
                    .shadow(6.dp, RoundedCornerShape(50),
                        spotColor = Theme.verdigris, ambientColor = Theme.verdigris)
                    .clickable(enabled = !refreshing) { scope.launch { refresh() } }) {
                Row(verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 7.dp)) {
                    if (refreshing) {
                        CircularProgressIndicator(color = Theme.ink, strokeWidth = 2.dp,
                            modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Refreshing…", color = Theme.ink, fontSize = 13.sp)
                    } else {
                        Text("↻", color = Theme.ink, fontSize = 14.sp, fontFamily = Theme.serif)
                        Spacer(Modifier.width(6.dp))
                        Text("Refresh", color = Theme.ink, fontSize = 13.sp)
                    }
                }
            }
        }
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

// Single on/off favorites toggle chip (Books tab only).
@Composable
private fun favChip(active: Boolean, onToggle: () -> Unit) {
    Surface(color = if (active) Theme.brass else Theme.surface2,
        shape = RoundedCornerShape(50),
        border = if (active) androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris) else null,
        modifier = Modifier
            .then(if (active) Modifier.shadow(8.dp, RoundedCornerShape(50),
                spotColor = Theme.verdigris, ambientColor = Theme.verdigris) else Modifier)
            .clickable { onToggle() }) {
        Text("★ Favorites", color = if (active) Theme.ink else Theme.parchmentMid, fontSize = 12.sp,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp))
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun BookCard(book: Book, api: ApiClient, wide: Boolean = false,
                      onOpen: () -> Unit, onToggleFavorite: () -> Unit) {
    val container = Modifier
        .combinedClickable(onClick = onOpen, onLongClick = onToggleFavorite)
        .electricPanel(Theme.surface, corner = 4.dp,
            alpha = if (book.isFavorite) 0.9f else 0.5f,
            elevation = if (book.isFavorite) 18.dp else 10.dp)
        .padding(10.dp)

    if (wide) {
        // One-per-row: cover on the left, full metadata + description on the right.
        Row(container.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Box {
                CoverImage(book, api, Modifier.size(100.dp, 150.dp).clip(RoundedCornerShape(2.dp)))
                if (book.isFavorite) {
                    Text("★", color = Theme.brassPale, fontSize = 16.sp,
                        modifier = Modifier.align(Alignment.TopEnd).padding(4.dp))
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(book.title, color = Theme.parchment, fontSize = 16.sp,
                    fontWeight = FontWeight.Bold, fontFamily = Theme.body, maxLines = 2)
                Spacer(Modifier.height(3.dp))
                Text(book.author, color = Theme.parchmentMid, fontSize = 13.sp, maxLines = 1)
                book.narrator?.let {
                    Spacer(Modifier.height(2.dp))
                    Text("Narrated by $it", color = Theme.parchmentDim, fontSize = 11.sp, maxLines = 1)
                }
                book.year?.let {
                    Spacer(Modifier.height(2.dp))
                    Text(it.toString(), color = Theme.parchmentDim, fontSize = 11.sp)
                }
                if (book.chapterCount > 0) {
                    Spacer(Modifier.height(2.dp))
                    Text("${book.listenedCount}/${book.chapterCount} listened",
                        color = Theme.parchmentDim, fontSize = 11.sp)
                }
                book.description?.takeIf { it.isNotBlank() }?.let {
                    Spacer(Modifier.height(4.dp))
                    Text(it, color = Theme.parchmentDim, fontSize = 11.sp, fontFamily = Theme.serif,
                        lineHeight = 15.sp, maxLines = 3,
                        overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                }
            }
        }
    } else {
        // Fixed text-row heights (title always 2 lines, author + narrator always
        // reserved) keep every tile the same height so the grid stays even.
        Column(container) {
            Box {
                CoverImage(book, api, Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(2.dp)))
                if (book.isFavorite) {
                    Text("★", color = Theme.brassPale, fontSize = 18.sp,
                        modifier = Modifier.align(Alignment.TopEnd).padding(6.dp))
                }
            }
            Spacer(Modifier.height(10.dp))
            Text(book.title, color = Theme.parchment, fontSize = 14.sp, minLines = 2, maxLines = 2)
            Spacer(Modifier.height(3.dp))
            Text(book.author, color = Theme.parchmentDim, fontSize = 12.sp, maxLines = 1)
            Spacer(Modifier.height(2.dp))
            Text(book.narrator ?: " ", color = Theme.parchmentDim, fontSize = 11.sp, maxLines = 1)
            Spacer(Modifier.height(2.dp))
        }
    }
}

@Composable
private fun CollectionCard(collection: Collection, api: ApiClient, onOpen: () -> Unit) {
    Column(
        Modifier
            .clickable(onClick = onOpen)
            .electricPanel(Theme.surface, corner = 4.dp, alpha = 0.7f, elevation = 12.dp)
            .padding(10.dp)
    ) {
        // Stacked "folder" look: two offset slips peek out behind the cover.
        Box(Modifier.fillMaxWidth().height(150.dp)) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 4.dp)
                    .fillMaxWidth(0.92f)
                    .height(146.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Theme.surface3))
            Box(
                Modifier
                    .align(Alignment.TopStart)
                    .padding(top = 2.dp)
                    .fillMaxWidth(0.96f)
                    .height(148.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Theme.surface2))
            CollectionCover(collection, api,
                Modifier.fillMaxWidth(0.94f).height(150.dp).clip(RoundedCornerShape(2.dp)))
            // "N books" badge, brass pill in the corner.
            Surface(color = Theme.brass, shape = RoundedCornerShape(50),
                border = androidx.compose.foundation.BorderStroke(1.dp, Theme.verdigris),
                modifier = Modifier.align(Alignment.BottomEnd).padding(6.dp)) {
                Text("${collection.bookCount} books", color = Theme.ink, fontSize = 11.sp,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp))
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(collection.name, color = Theme.parchment, fontSize = 14.sp, maxLines = 2)
        Spacer(Modifier.height(3.dp))
        Text("Collection", color = Theme.parchmentDim, fontSize = 11.sp, maxLines = 1)
        Spacer(Modifier.height(2.dp))
    }
}

// Small helper so chips get a clickable without importing the experimental API everywhere.
private fun Modifier.combinedClickableSafe(onClick: () -> Unit): Modifier =
    this.clickable(onClick = onClick)
