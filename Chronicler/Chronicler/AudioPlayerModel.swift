import Foundation
import AVFoundation
import MediaPlayer
import Combine

// Mirrors the AudioPlayer.razor native-player behavior:
// play/pause/seek/skip±30/rate, poll position, save progress every 10s, advance on end.
@MainActor
final class AudioPlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentPosition: Double = 0
    @Published var duration: Double = 0
    @Published var speed: Double = 1.0

    var onProgress: ((Double) -> Void)?
    var onEnded: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var lastSave = Date.distantPast
    private var currentURL: URL?
    private var token: String?
    private(set) var title = ""

    func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio)
        try? s.setActive(true)
    }

    // Load a chapter without auto-playing (matches OnParametersSetAsync resetting state).
    func load(url: URL, title: String, startPosition: Double, token: String?) {
        teardown()
        currentURL = url
        self.title = title
        self.token = token
        isPlaying = false
        currentPosition = startPosition
        duration = 0

        let asset = AVURLAsset(url: url, options: token.map {
            ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \($0)"]]
        })
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        p.rate = 0
        player = p

        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 4),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.tick(time) }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.ended() }
        }
    }

    private func tick(_ time: CMTime) {
        if isPlaying { currentPosition = time.seconds }
        if let d = player?.currentItem?.duration.seconds, d.isFinite, d > 0 { duration = d }
        if isPlaying, Date().timeIntervalSince(lastSave) >= 10 {
            lastSave = Date()
            onProgress?(currentPosition)
            updateNowPlaying()
        }
    }

    private func ended() {
        isPlaying = false
        onEnded?()
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            isPlaying = false
            player.rate = 0
            onProgress?(currentPosition)
        } else {
            configureSession()
            isPlaying = true
            // Seek to saved start position the first time we begin.
            if currentPosition > 1 {
                player.seek(to: CMTime(seconds: currentPosition, preferredTimescale: 600))
            }
            player.rate = Float(speed)
            updateNowPlaying()
        }
    }

    func skipBack()    { seek(to: max(0, currentPosition - 30)) }
    func skipForward() { seek(to: duration > 0 ? min(duration, currentPosition + 30) : currentPosition + 30) }

    func seek(to pos: Double) {
        currentPosition = pos
        player?.seek(to: CMTime(seconds: pos, preferredTimescale: 600))
        updateNowPlaying()
    }

    func setSpeed(_ s: Double) {
        speed = s
        if isPlaying { player?.rate = Float(s) }
    }

    func teardown() {
        if isPlaying { onProgress?(currentPosition) }
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPosition,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
