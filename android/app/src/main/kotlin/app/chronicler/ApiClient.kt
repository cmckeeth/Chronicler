package app.chronicler

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

// Kotlin port of Chronicler.Shared/Services/ApiClient.cs against the same .NET REST API.
class ApiClient {
    companion object { const val BASE_URL = "https://chronicler.mckeeth.app" }

    @Volatile var token: String? = null

    private val http = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    private fun builder(path: String, auth: Boolean = true): Request.Builder {
        val b = Request.Builder().url(BASE_URL + path)
        if (auth) token?.let { b.header("Authorization", "Bearer $it") }
        return b
    }

    private suspend fun body(req: Request): String? = withContext(Dispatchers.IO) {
        runCatching {
            http.newCall(req).execute().use { r -> if (r.isSuccessful) r.body?.string() else null }
        }.getOrNull()
    }

    private fun jsonBody(map: Map<String, Any?>) =
        kotlinx.serialization.json.JsonObject(map.mapValues { (_, v) ->
            when (v) {
                null -> kotlinx.serialization.json.JsonNull
                is Number -> kotlinx.serialization.json.JsonPrimitive(v)
                is Boolean -> kotlinx.serialization.json.JsonPrimitive(v)
                else -> kotlinx.serialization.json.JsonPrimitive(v.toString())
            }
        }).toString().toRequestBody("application/json".toMediaType())

    // ── Auth ──
    suspend fun login(email: String, password: String) = authCall("/api/auth/login", email, password)
    suspend fun register(email: String, password: String) = authCall("/api/auth/register", email, password)

    private suspend fun authCall(path: String, email: String, password: String): String? {
        val resp = body(builder(path, auth = false)
            .post(jsonBody(mapOf("email" to email, "password" to password))).build()) ?: return null
        return runCatching { json.decodeFromString<TokenResponse>(resp).token }.getOrNull()
    }

    // ── Books ──
    suspend fun getBooks(): List<Book> {
        val resp = body(builder("/api/books").build()) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Book>>(resp) }.getOrDefault(emptyList())
    }
    suspend fun getBook(id: Int): Book? {
        val resp = body(builder("/api/books/$id").build()) ?: return null
        return runCatching { json.decodeFromString<Book>(resp) }.getOrNull()
    }
    suspend fun coverBytes(bookId: Int): ByteArray? = withContext(Dispatchers.IO) {
        runCatching {
            http.newCall(builder("/api/books/$bookId/cover").build()).execute().use { r ->
                val bytes = if (r.isSuccessful) r.body?.bytes() else null
                if (bytes != null && bytes.size >= 100) bytes else null
            }
        }.getOrNull()
    }
    fun audioUrl(chapterId: Int) = "$BASE_URL/api/chapters/$chapterId/audio"

    suspend fun getChapters(bookId: Int): List<Chapter> {
        val resp = body(builder("/api/books/$bookId/chapters").build()) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Chapter>>(resp) }.getOrDefault(emptyList())
    }
    suspend fun getChapterProgress(chapterId: Int): ChapterProgress {
        val resp = body(builder("/api/chapters/$chapterId/progress").build())
            ?: return ChapterProgress()
        return runCatching { json.decodeFromString<ChapterProgress>(resp) }.getOrDefault(ChapterProgress())
    }
    suspend fun saveChapterProgress(chapterId: Int, position: Double, duration: Double) {
        body(builder("/api/chapters/$chapterId/progress")
            .put(jsonBody(mapOf("positionSeconds" to position, "durationSeconds" to duration))).build())
    }
    suspend fun resetChapter(chapterId: Int) {
        body(builder("/api/chapters/$chapterId/reset").post(ByteArray(0).toRequestBody()).build())
    }
    suspend fun resetBook(bookId: Int) {
        body(builder("/api/books/$bookId/reset").post(ByteArray(0).toRequestBody()).build())
    }
    suspend fun toggleFavorite(bookId: Int): Boolean {
        val resp = body(builder("/api/books/$bookId/favorite").post(ByteArray(0).toRequestBody()).build())
            ?: return false
        return runCatching { json.decodeFromString<FavoriteResult>(resp).isFavorite }.getOrDefault(false)
    }
    suspend fun getBookMeta(bookId: Int): BookMeta? {
        val resp = body(builder("/api/books/$bookId/meta").build()) ?: return null
        return runCatching { json.decodeFromString<BookMeta>(resp) }.getOrNull()
    }
    suspend fun saveBookMeta(bookId: Int, title: String, author: String, narrator: String?, year: Int?): Boolean {
        return body(builder("/api/books/$bookId/meta")
            .put(jsonBody(mapOf("title" to title, "author" to author,
                "narrator" to narrator, "description" to null, "year" to year))).build()) != null
    }
    suspend fun uploadCover(bookId: Int, image: ByteArray, mime: String): Boolean {
        val multipart = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("cover", "cover.jpg", image.toRequestBody(mime.toMediaType()))
            .build()
        return body(builder("/api/books/$bookId/cover/upload").put(multipart).build()) != null
    }

    // ── Updates ──
    suspend fun getLatestVersion(): String? {
        val resp = body(builder("/api/update/version", auth = false).build()) ?: return null
        return runCatching { json.decodeFromString<VersionResult>(resp).version }.getOrNull()
    }
    fun apkUrl() = "$BASE_URL/api/update/apk"

    @kotlinx.serialization.Serializable private data class TokenResponse(val token: String)
    @kotlinx.serialization.Serializable private data class FavoriteResult(val isFavorite: Boolean)
    @kotlinx.serialization.Serializable private data class VersionResult(val version: String)
}
