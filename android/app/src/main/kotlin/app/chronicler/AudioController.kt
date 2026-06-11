package app.chronicler

import android.content.Context
import android.media.audiofx.LoudnessEnhancer
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
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
    private val app = context.applicationContext
    private val exo = ExoPlayer.Builder(context)
        .setWakeMode(androidx.media3.common.C.WAKE_MODE_NETWORK)   // keep playing with screen off
        .setHandleAudioBecomingNoisy(true)
        .build()
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

    // Media session powering the lock-screen / notification controls.
    private val session = MediaSessionCompat(app, "Chronicler").apply {
        setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() { play() }
            override fun onPause() { if (isPlaying) togglePlay() }
            override fun onRewind() { skipBack() }
            override fun onFastForward() { skipForward() }
            override fun onSeekTo(pos: Long) { seek(pos / 1000.0) }
            override fun onStop() { if (isPlaying) togglePlay() }
        })
        isActive = true
        PlaybackHub.session = this
    }

    val castSupported = cast != null

    var isPlaying by mutableStateOf(false); private set
    var currentPosition by mutableDoubleStateOf(0.0); private set
    var duration by mutableDoubleStateOf(0.0); private set
    var speed by mutableDoubleStateOf(1.0); private set
    var title by mutableStateOf(""); private set
    var casting by mutableStateOf(false); private set
    var isLocal by mutableStateOf(false); private set   // playing a downloaded local file

    var onProgress: ((Double) -> Unit)? = null
    var onEnded: (() -> Unit)? = null

    private val listener = object : Player.Listener {
        override fun onIsPlayingChanged(playing: Boolean) {
            isPlaying = playing
            PlaybackHub.playing = playing
            updateSession()
            // Keep a foreground service (with media notification) alive across play/pause
            // so background/screen-off audio survives and lock-screen controls persist.
            PlaybackService.update(app)
        }
        override fun onPlaybackStateChanged(state: Int) {
            if (state == Player.STATE_ENDED) { isPlaying = false; onEnded?.invoke() }
        }
    }

    private fun updateSession() {
        session.setMetadata(MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, (duration * 1000).toLong())
            .build())
        session.setPlaybackState(PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or PlaybackStateCompat.ACTION_REWIND or
                PlaybackStateCompat.ACTION_FAST_FORWARD or PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP)
            .setState(
                if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                (currentPosition * 1000).toLong(), speed.toFloat())
            .build())
        PlaybackHub.title = title
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
        isLocal = url.startsWith("file:")
        currentPosition = startPosition
        duration = 0.0
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        if (startPosition > 1) player.seekTo((startPosition * 1000).toLong())
        updateSession()
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
                updateSession()   // keep lock-screen position/state fresh

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
        session.isActive = false
        session.release()
        PlaybackHub.session = null
        PlaybackService.stop(app)
    }
}
