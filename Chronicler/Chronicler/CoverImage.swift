import SwiftUI
import AVFoundation

// Loads cover bytes through the authed APIClient (mirrors GetCoverDataUriAsync) with a small cache.
actor CoverCache {
    static let shared = CoverCache()
    private var cache: [Int: Data] = [:]
    func data(for bookId: Int, api: APIClient) async -> Data? {
        if let cached = cache[bookId] { return cached }
        if let data = await api.coverData(bookId) {
            cache[bookId] = data
            // Keep a copy beside the audio so the offline library still has art.
            if Downloads.entry(bookId: bookId) != nil { Downloads.saveCover(bookId: bookId, data: data) }
            return data
        }
        // Server unreachable — fall back to the copy saved with the download.
        if let disk = Downloads.coverData(bookId: bookId) {
            cache[bookId] = disk
            return disk
        }
        return nil
    }
    func invalidate(_ bookId: Int) {
        cache[bookId] = nil
        Downloads.deleteCover(bookId: bookId)
    }
}

// Separate cache so collection ids don't collide with book ids in CoverCache.
actor CollectionCoverCache {
    static let shared = CollectionCoverCache()
    private var cache: [Int: Data] = [:]
    func data(for collectionId: Int, api: APIClient) async -> Data? {
        if let cached = cache[collectionId] { return cached }
        guard let data = await api.collectionCoverData(collectionId) else { return nil }
        cache[collectionId] = data
        return data
    }
}

struct CoverImage: View {
    let book: Book
    let api: APIClient
    var placeholderScale: CGFloat = 1

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .coverTreatment()
            } else if book.hasCover {
                placeholder(symbol: "⚙", opacity: 0.15)
            } else {
                placeholder(symbol: "📚", opacity: 1)
            }
        }
        .task(id: book.id) {
            guard book.hasCover else { return }
            if let data = await CoverCache.shared.data(for: book.id, api: api),
               let img = UIImage(data: data) { image = img }
        }
    }

    // Steampunk gives covers a warm sepia/aged wash; Tesla leaves them crisp + cool
    // (a touch of saturation/contrast so they read sharp against the blue glass).
    private func placeholder(symbol: String, opacity: Double) -> some View {
        ZStack {
            Theme.surface2
            Text(symbol).font(.system(size: 40 * placeholderScale)).opacity(opacity)
        }
    }
}

// Cover for a collection (mirrors CoverImage; folder symbol when no cover).
struct CollectionCoverImage: View {
    let collection: Collection
    let api: APIClient

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .coverTreatment()
            } else if collection.hasCover {
                placeholder(symbol: "⚙", opacity: 0.15)
            } else {
                placeholder(symbol: "📚", opacity: 1)
            }
        }
        .task(id: collection.id) {
            guard collection.hasCover else { return }
            if let data = await CollectionCoverCache.shared.data(for: collection.id, api: api),
               let img = UIImage(data: data) { image = img }
        }
    }

    private func placeholder(symbol: String, opacity: Double) -> some View {
        ZStack {
            Theme.surface2
            Text(symbol).font(.system(size: 40)).opacity(opacity)
        }
    }
}

extension View {
    // Per-theme cover look. Steampunk = aged sepia (warm tint + slight desaturation).
    // Tesla = crisp/cool (no sepia; faintly punchier so it pops against the glass).
    @ViewBuilder func coverTreatment() -> some View {
        if Theme.mode == .steampunk {
            self
                .saturation(0.5)
                .colorMultiply(Color(hex: 0xd8b070))
                .brightness(-0.12)        // aged ~.88 brightness
                .contrast(1.05)
        } else if Theme.mode == .west {
            // West = sun-baked: warm amber wash, desaturated, dimmed like old paper.
            self
                .saturation(0.72)
                .colorMultiply(Color(hex: 0xe8c088))
                .brightness(-0.08)
                .contrast(1.06)
        } else if Theme.mode == .garden {
            // Garden = lush/crisp: a saturation bump, no sepia, so foliage pops.
            self
                .saturation(1.15)
                .contrast(1.04)
        } else {
            // Tesla = cool/crisp.
            self
                .saturation(1.08)
                .brightness(-0.02)        // ~.98 brightness
                .contrast(1.05)
        }
    }
}

// Startup sound (commit: "Play startup sound on app open").
final class StartupSound {
    static let shared = StartupSound()
    private var player: AVAudioPlayer?
    private var played = false          // once per app launch, not every time Landing appears
    // force == false: the once-per-launch chime (Landing onAppear).
    // force == true: replay on a theme switch, so each theme's sound is heard immediately.
    func play(force: Bool = false) {
        if !force {
            guard !played else { return }
            played = true
        }
        // Per-theme sound (startup_tesla / startup_steampunk / startup_garden); fall back
        // to the generic startup.mp3 if a themed file isn't bundled yet.
        let themed = "startup_\(Theme.mode.rawValue)"
        guard let url = Bundle.main.url(forResource: themed, withExtension: "mp3")
                ?? Bundle.main.url(forResource: "startup", withExtension: "mp3") else { return }
        // .playback (not .ambient) so the chime is heard even with the ring/silent switch
        // on; mixWithOthers so it layers over any playing audio instead of stopping it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
