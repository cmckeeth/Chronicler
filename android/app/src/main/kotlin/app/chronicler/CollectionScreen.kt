package app.chronicler

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.launch

@Composable
fun CollectionScreen(auth: AuthStore, nav: NavController, collectionId: Int) {
    var collection by remember { mutableStateOf<Collection?>(null) }
    var books by remember { mutableStateOf<List<Book>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    suspend fun load() {
        loading = true; error = null
        runCatching {
            collection = auth.api.collections().firstOrNull { it.id == collectionId }
            books = auth.api.collectionBooks(collectionId)
        }.onFailure { error = "unreachable" }
        loading = false
    }
    LaunchedEffect(collectionId) { load() }

    // Honor the server's order (manual SortOrder, then alphabetical) — no client resort.
    val sorted = books

    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 14.dp)) {
        TextButton(onClick = { nav.popBackStack() },
            contentPadding = PaddingValues(0.dp)) {
            Text("‹ The Archive", color = Theme.brass)
        }
        Spacer(Modifier.height(6.dp))
        Text(collection?.name ?: "Collection", color = Theme.brass, fontSize = 24.sp,
            fontWeight = FontWeight.Bold, fontFamily = Theme.serif, letterSpacing = 2.sp,
            style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
            modifier = Modifier.align(Alignment.CenterHorizontally).padding(vertical = 6.dp))
        Spacer(Modifier.height(18.dp))

        when {
            loading -> center("Consulting the archive...", Theme.parchmentDim)
            error != null -> center("The pneumatic tubes have failed: $error", Theme.rust)
            sorted.isEmpty() -> center("This collection lies empty, traveller.", Theme.parchmentDim)
            else -> LazyVerticalGrid(columns = GridCells.Fixed(3),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
                contentPadding = PaddingValues(vertical = 4.dp)) {
                items(sorted, key = { it.id }) { book ->
                    BookCard(book, auth.api, onOpen = { nav.navigate("book/${book.id}") },
                        onToggleFavorite = { scope.launch { auth.api.toggleFavorite(book.id); load() } })
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
