import Foundation

// Offline downloads: stores chapter audio under Caches/downloads/<chapterId>.audio
// and serves a local file URL when present so playback works without the network.
// Swift port of Android's Downloads object.
enum Downloads {
    private static func dir() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func file(chapterId: Int) -> URL {
        dir().appendingPathComponent("\(chapterId).audio")
    }

    static func isDownloaded(chapterId: Int) -> Bool {
        let url = file(chapterId: chapterId)
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else {
            return false
        }
        return size > 0
    }

    /// Local file URL if downloaded, else the streaming URL.
    static func sourceURL(chapterId: Int, streamURL: URL) -> URL {
        isDownloaded(chapterId: chapterId) ? file(chapterId: chapterId) : streamURL
    }

    /// Downloads a chapter's audio to disk. Returns true on success.
    static func download(chapterId: Int, url: URL, token: String?) async -> Bool {
        var req = URLRequest(url: url)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        do {
            let (tmp, resp) = try await URLSession.shared.download(for: req)
            guard let code = (resp as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
                return false
            }
            let dest = file(chapterId: chapterId)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            return isDownloaded(chapterId: chapterId)
        } catch {
            return false
        }
    }

    static func deleteChapter(chapterId: Int) {
        try? FileManager.default.removeItem(at: file(chapterId: chapterId))
    }
}
