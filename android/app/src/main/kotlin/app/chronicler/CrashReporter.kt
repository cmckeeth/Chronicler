package app.chronicler

import java.io.PrintWriter
import java.io.StringWriter
import java.net.HttpURLConnection
import java.net.URL

// Reports uncaught exceptions to the server's /api/diag (visible via /api/logs),
// so crashes on a real device can be diagnosed without a debugger attached.
object CrashReporter {
    fun install() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            runCatching {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val trace = sw.toString().take(4000)
                // Wait for the POST (main is already dying).
                post("ANDROID CRASH v${BuildConfig.VERSION_NAME}: $trace").join(3000)
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    /** Sends a line to the server log without crashing, e.g. a playback error nothing else would surface. */
    fun report(message: String) { runCatching { post("ANDROID v${BuildConfig.VERSION_NAME}: $message") } }

    private fun post(msg: String): Thread {
        // Build valid JSON (proper escaping of tabs/quotes/newlines in the trace).
        val body = kotlinx.serialization.json.JsonObject(
            mapOf("message" to kotlinx.serialization.json.JsonPrimitive(msg))).toString()
        // POST on a short-lived thread so callers on main never block on the network.
        return Thread {
            runCatching {
                val conn = (URL("${ApiClient.BASE_URL}/api/diag").openConnection() as HttpURLConnection)
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                conn.outputStream.use { it.write(body.toByteArray()) }
                conn.inputStream.use { it.readBytes() }
            }
        }.apply { start() }
    }
}
