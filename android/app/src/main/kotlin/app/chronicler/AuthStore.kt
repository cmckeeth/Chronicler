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

    // Persisted: boost playback volume beyond 100%.
    var volumeBoosted by mutableStateOf(prefs.getBoolean("volumeBoost", false))
        private set

    fun setVolumeBoost(v: Boolean) {
        volumeBoosted = v
        prefs.edit().putBoolean("volumeBoost", v).apply()
    }

    // Persisted: archive grid density (1 / 2 / 3 columns).
    var gridColumns by mutableStateOf(prefs.getInt("gridColumns", 3))
        private set

    fun setGridSize(v: Int) {
        gridColumns = v
        prefs.edit().putInt("gridColumns", v).apply()
    }

    // Persisted: the active visual theme (Tesla vs. Steampunk). Stored as the enum name.
    fun loadThemeMode(): ThemeMode =
        runCatching { ThemeMode.valueOf(prefs.getString("theme", null) ?: "") }
            .getOrDefault(ThemeMode.TESLA)

    fun setThemeMode(mode: ThemeMode) {
        Theme.themeMode = mode
        prefs.edit().putString("theme", mode.name).apply()
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
