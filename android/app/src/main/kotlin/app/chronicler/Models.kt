package app.chronicler

import kotlinx.serialization.Serializable

// Mirrors the C# DTOs (System.Text.Json Web defaults => camelCase keys).
@Serializable
data class Book(
    val id: Int,
    val title: String,
    val author: String,
    val narrator: String? = null,
    val durationSeconds: Double = 0.0,
    val hasCover: Boolean = false,
    val addedAt: String = "",
    val chapterCount: Int = 0,
    val listenedCount: Int = 0,
    val year: Int? = null,
    val isFavorite: Boolean = false,
    val collectionId: Int? = null,
) {
    val isCompleted get() = chapterCount > 0 && listenedCount >= chapterCount
    val isInProgress get() = listenedCount > 0 && !isCompleted
}

@Serializable
data class Collection(
    val id: Int,
    val name: String,
    val hasCover: Boolean,
    val bookCount: Int,
    val addedAt: String? = null,
)

@Serializable
data class Chapter(val id: Int, val bookId: Int, val title: String, val trackNumber: Int)

@Serializable
data class ChapterProgress(val positionSeconds: Double = 0.0, val isListened: Boolean = false)

@Serializable
data class BookMeta(
    val id: Int,
    val title: String,
    val author: String,
    val narrator: String? = null,
    val description: String? = null,
    val year: Int? = null,
)
