import SwiftUI
import AVFoundation

// Loads cover bytes through the authed APIClient (mirrors GetCoverDataUriAsync) with a small cache.
actor CoverCache {
    static let shared = CoverCache()
    private var cache: [Int: Data] = [:]
    func data(for bookId: Int, api: APIClient) async -> Data? {
        if let cached = cache[bookId] { return cached }
        guard let data = await api.coverData(bookId) else { return nil }
        cache[bookId] = data
        return data
    }
    func invalidate(_ bookId: Int) { cache[bookId] = nil }
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

    private func placeholder(symbol: String, opacity: Double) -> some View {
        ZStack {
            Theme.surface2
            Text(symbol).font(.system(size: 40 * placeholderScale)).opacity(opacity)
        }
    }
}

// Startup sound (commit: "Play startup sound on app open").
final class StartupSound {
    static let shared = StartupSound()
    private var player: AVAudioPlayer?
    func play() {
        guard let url = Bundle.main.url(forResource: "startup", withExtension: "mp3") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
