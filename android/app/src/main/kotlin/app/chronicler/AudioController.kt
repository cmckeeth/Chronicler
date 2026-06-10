package app.chronicler

import android.content.Context
import android.media.audiofx.LoudnessEnhancer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.media3.cast.CastPlayer
import androidx.media3.cast.SessionAvailabilityListener
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import com.google.android.gms.cast.framework.CastContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Plays locally via ExoPlayer, or on a Chromecast/Google TV/Nest via CastPlayer.
// Both implement Player, so controls/position work uniformly; we just swap which
// one is active when a cast session connects/disconnects, transferring the media.
@UnstableApi
class AudioController(context: Context) {
    private val exo = ExoPlayer.Builder(context).build()
    private val cast: CastPlayer? = runCatching {
        CastPlayer(CastContext.getSharedInstance(context))
    }.getOrNull()

    private var player: Player = exo
    private var pollJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private var lastSaveMs = 0L

    // Volume boost on local playback via LoudnessEnhancer (gain beyond 100%).
    private var enhancer: LoudnessEnhancer? = null
    private var boostEnabled = false
    private val boostGainMillibels = 1200   // ~12 dB

    val castSupported = cast != null

    var isPlaying by mutableStateOf(false); private set
    var currentPosition by mutableDoubleStateOf(0.0); private set
    var duration by mutableDoubleStateOf(0.0); private set
    var speed by mutableDoubleStateOf(1.0); private set
    var title by mutableStateOf(""); private set
    var casting by mutableStateOf(false); private set

    var onProgress: ((Double) -> Unit)? = null
    var onEnded: (() -> Unit)? = null

    private val listener = object : Player.Listener {
        override fun onIsPlayingChanged(playing: Boolean) { isPlaying = playing }
        override fun onPlaybackStateChanged(state: Int) {
            if (state == Player.STATE_ENDED) { isPlaying = false; onEnded?.invoke() }
        }
    }

    init {
        exo.addListener(listener)
        cast?.addListener(listener)
        cast?.setSessionAvailabilityListener(object : SessionAvailabilityListener {
            override fun onCastSessionAvailable() { transferTo(cast) }
            override fun onCastSessionUnavailable() { transferTo(exo) }
        })
        exo.addAnalyticsListener(object : AnalyticsListener {
            override fun onAudioSessionIdChanged(eventTime: AnalyticsListener.EventTime, audioSessionId: Int) {
                setupEnhancer(audioSessionId)
            }
        })
        startPolling()
    }

    private fun setupEnhancer(sessionId: Int) {
        enhancer?.release()
        enhancer = runCatching {
            LoudnessEnhancer(sessionId).apply {
                setTargetGain(if (boostEnabled) boostGainMillibels else 0)
                enabled = boostEnabled
            }
        }.getOrNull()
    }

    fun setBoost(on: Boolean) {
        boostEnabled = on
        runCatching {
            enhancer?.setTargetGain(if (on) boostGainMillibels else 0)
            enhancer?.enabled = on
        }
    }

    private fun transferTo(target: Player) {
        if (target === player) return
        val pos = player.currentPosition
        val wasPlaying = player.isPlaying
        val item = player.currentMediaItem
        player.pause()
        player = target
        casting = player === cast
        if (item != null) {
            player.setMediaItem(item, pos)
            player.playbackParameters = player.playbackParameters.withSpeed(speed.toFloat())
            player.prepare()
            if (wasPlaying) player.play()
        }
    }

    fun load(url: String, title: String, startPosition: Double, @Suppress("UNUSED_PARAMETER") token: String?) {
        this.title = title
        currentPosition = startPosition
        duration = 0.0
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        if (startPosition > 1) player.seekTo((startPosition * 1000).toLong())
    }

    private fun startPolling() {
        pollJob?.cancel()
        pollJob = scope.launch {
            while (true) {
                delay(250)
                if (player.isPlaying) currentPosition = player.currentPosition / 1000.0
                val d = player.duration
                if (d > 0) duration = d / 1000.0
                if (player.isPlaying && System.currentTimeMillis() - lastSaveMs >= 10_000) {
                    lastSaveMs = System.currentTimeMillis()
                    onProgress?.invoke(currentPosition)
                }
            }
        }
    }

    fun togglePlay() {
        if (player.isPlaying) {
            player.pause()
            onProgress?.invoke(currentPosition)
        } else {
            player.playbackParameters = player.playbackParameters.withSpeed(speed.toFloat())
            player.play()
        }
    }

    fun play() { if (!player.isPlaying) togglePlay() }

    fun skipBack() = seek(maxOf(0.0, currentPosition - 30))
    fun skipForward() = seek(if (duration > 0) minOf(duration, currentPosition + 30) else currentPosition + 30)

    fun seek(pos: Double) {
        currentPosition = pos
        player.seekTo((pos * 1000).toLong())
    }

    fun setRate(s: Double) {
        speed = s
        player.playbackParameters = player.playbackParameters.withSpeed(s.toFloat())
    }

    fun release() {
        if (player.isPlaying) onProgress?.invoke(currentPosition)
        pollJob?.cancel()
        cast?.setSessionAvailabilityListener(null)
        enhancer?.release()
        exo.release()
        cast?.release()
    }
}
