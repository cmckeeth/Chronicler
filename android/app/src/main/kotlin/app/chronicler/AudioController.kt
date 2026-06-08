package app.chronicler

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Mirrors AudioPlayer.razor native behavior: skip ±30, speed, poll, save every 10s, advance on end.
class AudioController(context: Context) {
    private val player = ExoPlayer.Builder(context).build()
    private var pollJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private var lastSaveMs = 0L

    var isPlaying by mutableStateOf(false); private set
    var currentPosition by mutableDoubleStateOf(0.0); private set
    var duration by mutableDoubleStateOf(0.0); private set
    var speed by mutableDoubleStateOf(1.0); private set
    var title by mutableStateOf(""); private set

    var onProgress: ((Double) -> Unit)? = null
    var onEnded: (() -> Unit)? = null

    init {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED) { isPlaying = false; onEnded?.invoke() }
            }
        })
    }

    fun load(url: String, title: String, startPosition: Double, token: String?) {
        this.title = title
        isPlaying = false
        currentPosition = startPosition
        duration = 0.0

        val dsf = DefaultHttpDataSource.Factory().apply {
            if (token != null) setDefaultRequestProperties(mapOf("Authorization" to "Bearer $token"))
        }
        val source = ProgressiveMediaSource.Factory(dsf)
            .createMediaSource(MediaItem.fromUri(url))
        player.setMediaSource(source)
        player.prepare()
        if (startPosition > 1) player.seekTo((startPosition * 1000).toLong())
        startPolling()
    }

    private fun startPolling() {
        pollJob?.cancel()
        pollJob = scope.launch {
            while (true) {
                delay(250)
                if (isPlaying) currentPosition = player.currentPosition / 1000.0
                val d = player.duration
                if (d > 0) duration = d / 1000.0
                if (isPlaying && System.currentTimeMillis() - lastSaveMs >= 10_000) {
                    lastSaveMs = System.currentTimeMillis()
                    onProgress?.invoke(currentPosition)
                }
            }
        }
    }

    fun togglePlay() {
        if (isPlaying) {
            isPlaying = false
            player.pause()
            onProgress?.invoke(currentPosition)
        } else {
            isPlaying = true
            player.playbackParameters = PlaybackParameters(speed.toFloat())
            player.play()
        }
    }

    fun play() { if (!isPlaying) togglePlay() }

    fun skipBack() = seek(maxOf(0.0, currentPosition - 30))
    fun skipForward() = seek(if (duration > 0) minOf(duration, currentPosition + 30) else currentPosition + 30)

    fun seek(pos: Double) {
        currentPosition = pos
        player.seekTo((pos * 1000).toLong())
    }

    fun setRate(s: Double) {
        speed = s
        player.playbackParameters = PlaybackParameters(s.toFloat())
    }

    fun release() {
        if (isPlaying) onProgress?.invoke(currentPosition)
        pollJob?.cancel()
        player.release()
    }
}
