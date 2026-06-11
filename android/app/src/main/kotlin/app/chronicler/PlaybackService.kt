package app.chronicler

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media.session.MediaButtonReceiver

// Shared handle to the media session so the service (notification + media buttons)
// and the AudioController (which owns the player) can both reach it.
object PlaybackHub {
    var session: MediaSessionCompat? = null
    var playing = false
    var title = ""
}

// Foreground media service: keeps background/screen-off audio alive AND shows the
// lock-screen / notification transport controls (rewind 30 · play/pause · forward 30).
class PlaybackService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Route media-button / action presses to the session callback.
        PlaybackHub.session?.let { MediaButtonReceiver.handleIntent(it, intent) }

        val channelId = "chronicler_playback"
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(channelId) == null) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Playback", NotificationManager.IMPORTANCE_LOW))
        }

        val token = PlaybackHub.session?.sessionToken
        val playing = PlaybackHub.playing
        val contentPi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Chronicler")
            .setContentText(PlaybackHub.title.ifBlank { "Playing" })
            .setSmallIcon(R.drawable.logo)
            .setContentIntent(contentPi)
            .setOngoing(playing)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_media_rew, "Rewind",
                MediaButtonReceiver.buildMediaButtonPendingIntent(this, PlaybackStateCompat.ACTION_REWIND))
            .addAction(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "Pause" else "Play",
                MediaButtonReceiver.buildMediaButtonPendingIntent(this, PlaybackStateCompat.ACTION_PLAY_PAUSE))
            .addAction(android.R.drawable.ic_media_ff, "Forward",
                MediaButtonReceiver.buildMediaButtonPendingIntent(this, PlaybackStateCompat.ACTION_FAST_FORWARD))

        val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
        if (token != null) mediaStyle.setMediaSession(token)
        builder.setStyle(mediaStyle)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(1, builder.build())
        }
        return START_STICKY
    }

    companion object {
        fun update(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, PlaybackService::class.java))
        }
        fun start(context: Context) = update(context)
        fun stop(context: Context) {
            context.stopService(Intent(context, PlaybackService::class.java))
        }
    }
}
