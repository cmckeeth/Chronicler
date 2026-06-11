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
    // Source: true when playing a downloaded local file (mirrors Android AudioController.isLocal).
    @Published var isLocal = false
    // Whether the audio output is currently routed to AirPlay / an external device.
    @Published var isAirPlay = false

    var onProgress: ((Double) -> Void)?
    var onEnded: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private var lastSave = Date.distantPast
    private var currentURL: URL?
    private var token: String?
    private(set) var title = ""

    // Volume boost (~12 dB) applied via an MTAudioProcessingTap on the player item's
    // audio mix. ~4x linear gain ≈ +12 dB, matching Android's LoudnessEnhancer.
    private var boostEnabled = false
    private static let boostGain: Float = 4.0   // ≈ +12 dB

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
        isLocal = url.isFileURL
        currentPosition = startPosition
        duration = 0

        let asset: AVURLAsset
        if url.isFileURL {
            asset = AVURLAsset(url: url)
        } else {
            asset = AVURLAsset(url: url, options: token.map {
                ["AVURLAssetHTTPHeaderFieldsKey": ["Authorization": "Bearer \($0)"]]
            })
        }
        let item = AVPlayerItem(asset: asset)
        applyBoost(to: item)
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
        observeRouteChanges()
        updateRoute()
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

    // Start playback programmatically (used by autoplay-next).
    func play() { if !isPlaying { togglePlay() } }

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

    // Volume boost toggle. Applied to the current item immediately and to future loads.
    func setBoost(_ on: Bool) {
        boostEnabled = on
        if let item = player?.currentItem { applyBoost(to: item) }
    }

    func teardown() {
        if isPlaying { onProgress?(currentPosition) }
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        routeObserver = nil
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

    // ── AirPlay route tracking ──
    private func observeRouteChanges() {
        guard routeObserver == nil else { return }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateRoute() }
        }
    }

    private func updateRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        isAirPlay = outputs.contains { $0.portType == .airPlay }
    }

    // ── Volume boost via MTAudioProcessingTap ──
    private func applyBoost(to item: AVPlayerItem) {
        guard let track = item.asset.tracks(withMediaType: .audio).first else {
            // Tracks may not be loaded synchronously for remote assets; load then retry.
            item.asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self, weak item] in
                Task { @MainActor in
                    guard let self, let item,
                          item.asset.tracks(withMediaType: .audio).first != nil else { return }
                    self.applyBoost(to: item)
                }
            }
            return
        }
        let gain = boostEnabled ? Self.boostGain : 1.0
        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = Self.makeTap(gain: gain)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        item.audioMix = mix
    }

    // Builds an MTAudioProcessingTap that multiplies every float sample by `gain`,
    // clamping to [-1, 1] to avoid hard clipping artifacts.
    private static func makeTap(gain: Float) -> MTAudioProcessingTap? {
        let gainBox = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        gainBox.initialize(to: gain)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(gainBox),
            init: { _, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let storage = MTAudioProcessingTapGetStorage(tap)
                storage.assumingMemoryBound(to: Float.self).deallocate()
            },
            prepare: nil,
            unprepare: nil,
            process: { tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(
                    tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
                guard status == noErr else { return }
                let g = MTAudioProcessingTapGetStorage(tap).assumingMemoryBound(to: Float.self).pointee
                if g == 1.0 { return }
                let buffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    let samples = data.assumingMemoryBound(to: Float.self)
                    for i in 0..<count {
                        let v = samples[i] * g
                        samples[i] = v > 1 ? 1 : (v < -1 ? -1 : v)
                    }
                }
            })

        var tap: MTAudioProcessingTap?
        let err = MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        guard err == noErr else {
            gainBox.deallocate()
            return nil
        }
        return tap
    }
}
