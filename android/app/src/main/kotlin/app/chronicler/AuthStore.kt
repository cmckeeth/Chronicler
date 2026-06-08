package app.chronicler

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class AuthStore(context: Context) {
    private val prefs = context.getSharedPreferences("chronicler", Context.MODE_PRIVATE)
    val api = ApiClient()

    var isAuthenticated by mutableStateOf(false)
        private set
    var email by mutableStateOf<String?>(null)
        private set

    // Persisted: auto-play the next chapter when one finishes.
    var autoplayNext by mutableStateOf(prefs.getBoolean("autoplay", false))
        private set

    fun setAutoplay(v: Boolean) {
        autoplayNext = v
        prefs.edit().putBoolean("autoplay", v).apply()
    }

    init {
        prefs.getString("token", null)?.let {
            api.token = it
            email = prefs.getString("email", null)
            isAuthenticated = true
        }
    }

    fun setToken(token: String, email: String) {
        api.token = token
        this.email = email
        prefs.edit().putString("token", token).putString("email", email).apply()
        isAuthenticated = true
    }

    fun clear() {
        api.token = null
        email = null
        prefs.edit().remove("token").remove("email").apply()
        isAuthenticated = false
    }
}
