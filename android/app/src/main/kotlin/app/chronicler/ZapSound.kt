package app.chronicler

import android.content.Context
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.tanh

// Synthesizes a short "electric zap" at runtime (no audio asset needed):
// a descending tone + noise, distorted and decayed — plays on play/pause tap.
object ZapSound {
    fun play(context: Context) {
        Thread {
            runCatching {
                val sr = 44100
                val durSec = 0.16
                val n = (sr * durSec).toInt()
                val samples = ShortArray(n)
                var phase = 0.0
                var seed = 0x2545F4914F6CDD1DL
                for (i in 0 until n) {
                    val prog = i.toDouble() / n
                    val freq = 1500.0 * (1 - prog) + 180.0      // sweep high -> low
                    phase += 2 * PI * freq / sr
                    // cheap deterministic noise
                    seed = seed * 6364136223846793005L + 1442695040888963407L
                    val noise = (seed ushr 40).toDouble() / (1L shl 24) * 2 - 1
                    var v = 0.6 * sin(phase) + 0.4 * noise
                    v = tanh(v * 2.8)                            // crunch / distortion
                    val env = exp(-prog * 5.5)                  // fast decay
                    samples[i] = (v * env * Short.MAX_VALUE * 0.5).toInt().toShort()
                }
                @Suppress("DEPRECATION")
                val track = AudioTrack(
                    AudioManager.STREAM_MUSIC, sr,
                    AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    samples.size * 2, AudioTrack.MODE_STATIC)
                track.write(samples, 0, samples.size)
                track.play()
                Thread.sleep((durSec * 1000).toLong() + 80)
                track.release()
            }
        }.start()
    }
}
