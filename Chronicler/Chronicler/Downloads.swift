import Foundation

// A book whose chapters have been downloaded: enough metadata to list and play it
// with the server unreachable. Written to manifest.json beside the audio files.
struct DownloadedBook: Codable, Identifiable, Hashable {
    var book: Book
    var chapters: [Chapter]
    var id: Int { book.id }
}

// Chapter progress kept on disk so offline playback resumes in the right place.
// `dirty` marks progress recorded while the server was unreachable; it gets pushed
// on the next load that reaches the API.
struct StoredProgress: Codable {
    var positionSeconds: Double = 0
    var durationSeconds: Double = 0
    var isListened: Bool = false
    var dirty: Bool = false
}

// Offline downloads: stores chapter audio under downloads/<chapterId>.audio, the book +
// chapter metadata in manifest.json, the cover in cover-<bookId>.img, and chapter progress
// in progress.json — so the whole offline library works without a single network call.
// Swift port of Android's Downloads object.
enum Downloads {
    private static let lock = NSLock()

    // Downloads live in Application Support: Caches can be evicted by iOS under storage
    // pressure, which is exactly when you'd want your offline books. Anything left in the
    // old Caches/downloads location is moved over on first use.
    private static let root: URL = {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var dir = base.appendingPathComponent("downloads", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true          // re-downloadable content
        try? dir.setResourceValues(values)

        let old = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("downloads", isDirectory: true)
        if old.path != dir.path,
           let items = try? fm.contentsOfDirectory(at: old, includingPropertiesForKeys: nil) {
            for item in items {
                let dest = dir.appendingPathComponent(item.lastPathComponent)
                if !fm.fileExists(atPath: dest.path) { try? fm.moveItem(at: item, to: dest) }
            }
            try? fm.removeItem(at: old)
        }

        // Older builds saved every download as "<id>.audio", which AVFoundation can't
        // type and so plays silence. Rename them to the common case (mp3).
        if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension == "audio" {
                let renamed = item.deletingPathExtension().appendingPathExtension("mp3")
                if !fm.fileExists(atPath: renamed.path) { try? fm.moveItem(at: item, to: renamed) }
            }
        }
        return dir
    }()

    private static func dir() -> URL { root }

    /// The audio file on disk for a chapter, whatever extension it was saved with.
    static func file(chapterId: Int) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir(),
                                                                  includingPropertiesForKeys: nil)) ?? []
        return items.first { $0.deletingPathExtension().lastPathComponent == String(chapterId) }
    }

    // AVFoundation picks a decoder off the file extension, so a download saved as a
    // generic ".audio" silently plays nothing. Map the server's mime onto a real one.
    static func fileExtension(for mimeType: String?) -> String {
        switch (mimeType ?? "").lowercased() {
        case let m where m.contains("mp4") || m.contains("m4a") || m.contains("m4b") || m.contains("aac"):
            return "m4a"
        case let m where m.contains("ogg") || m.contains("opus"): return "ogg"
        case let m where m.contains("flac"): return "flac"
        case let m where m.contains("wav"): return "wav"
        default: return "mp3"
        }
    }

    static func isDownloaded(chapterId: Int) -> Bool {
        guard let url = file(chapterId: chapterId),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        else { return false }
        return size > 0
    }

    /// Local file URL if downloaded, else the streaming URL.
    static func sourceURL(chapterId: Int, streamURL: URL) -> URL {
        isDownloaded(chapterId: chapterId) ? (file(chapterId: chapterId) ?? streamURL) : streamURL
    }

    /// Downloads a chapter's audio to disk. Returns true on success.
    static func download(chapterId: Int, url: URL, token: String?, mimeType: String? = nil) async -> Bool {
        var req = URLRequest(url: url)
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        do {
            let (tmp, resp) = try await URLSession.shared.download(for: req)
            let http = resp as? HTTPURLResponse
            guard let code = http?.statusCode, (200..<300).contains(code) else { return false }
            // Prefer what the server actually served over the chapter's declared mime.
            let ext = fileExtension(for: http?.mimeType ?? mimeType)
            deleteChapter(chapterId: chapterId)
            let dest = dir().appendingPathComponent("\(chapterId).\(ext)")
            try FileManager.default.moveItem(at: tmp, to: dest)
            return isDownloaded(chapterId: chapterId)
        } catch {
            return false
        }
    }

    static func deleteChapter(chapterId: Int) {
        if let existing = file(chapterId: chapterId) {
            try? FileManager.default.removeItem(at: existing)
        }
    }

    // ── Manifest (which books/chapters the downloads belong to) ──

    private static var manifestFile: URL { dir().appendingPathComponent("manifest.json") }

    private static func readManifest() -> [Int: DownloadedBook] {
        guard let data = try? Data(contentsOf: manifestFile),
              let raw = try? JSONDecoder().decode([String: DownloadedBook].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
    }

    private static func writeManifest(_ manifest: [Int: DownloadedBook]) {
        let raw = Dictionary(uniqueKeysWithValues: manifest.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            try? data.write(to: manifestFile, options: .atomic)
        }
    }

    /// Remembers a book + its chapter list so the offline library can list and play it.
    static func record(book: Book, chapters: [Chapter]) {
        guard !chapters.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        var manifest = readManifest()
        manifest[book.id] = DownloadedBook(book: book, chapters: chapters)
        writeManifest(manifest)
    }

    static func entry(bookId: Int) -> DownloadedBook? {
        lock.lock(); defer { lock.unlock() }
        return readManifest()[bookId]
    }

    /// Books with at least one chapter still on disk, A→Z by title.
    static func downloadedBooks() -> [DownloadedBook] {
        lock.lock()
        let all = readManifest()
        lock.unlock()
        return all.values
            .filter { entry in entry.chapters.contains { isDownloaded(chapterId: $0.id) } }
            .sorted { $0.book.title.lowercased() < $1.book.title.lowercased() }
    }

    static func hasAny() -> Bool {
        // Cheap check: any chapter file (named "<chapterId>.<ext>") at all.
        let items = (try? FileManager.default.contentsOfDirectory(at: dir(),
                                                                  includingPropertiesForKeys: nil)) ?? []
        return items.contains { Int($0.deletingPathExtension().lastPathComponent) != nil }
    }

    static func downloadedCount(bookId: Int) -> Int {
        entry(bookId: bookId)?.chapters.filter { isDownloaded(chapterId: $0.id) }.count ?? 0
    }

    static func size(bookId: Int) -> Int64 {
        guard let entry = entry(bookId: bookId) else { return 0 }
        return entry.chapters.reduce(0) { total, chapter in
            guard let path = file(chapterId: chapter.id)?.path,
                  let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return total }
            return total + ((attrs[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    static func totalSize() -> Int64 {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dir(), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return items
            .filter { Int($0.deletingPathExtension().lastPathComponent) != nil }   // audio only
            .reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    /// Deletes every downloaded chapter of a book plus its cached cover + manifest entry.
    static func deleteBook(bookId: Int) {
        entry(bookId: bookId)?.chapters.forEach { deleteChapter(chapterId: $0.id) }
        deleteCover(bookId: bookId)
        lock.lock()
        var manifest = readManifest()
        manifest[bookId] = nil
        writeManifest(manifest)
        lock.unlock()
    }

    /// Drops the manifest entry once the last chapter of a book has been removed.
    static func pruneIfEmpty(bookId: Int) {
        guard let entry = entry(bookId: bookId) else { return }
        guard !entry.chapters.contains(where: { isDownloaded(chapterId: $0.id) }) else { return }
        deleteBook(bookId: bookId)
    }

    // ── Cover (kept beside the audio so the offline library isn't a wall of placeholders) ──

    static func coverFile(bookId: Int) -> URL {
        dir().appendingPathComponent("cover-\(bookId).img")
    }
    static func saveCover(bookId: Int, data: Data) {
        try? data.write(to: coverFile(bookId: bookId), options: .atomic)
    }
    static func coverData(bookId: Int) -> Data? {
        try? Data(contentsOf: coverFile(bookId: bookId))
    }
    static func deleteCover(bookId: Int) {
        try? FileManager.default.removeItem(at: coverFile(bookId: bookId))
    }
    /// Fetches and stores the cover for a downloaded book (no-op if it can't be fetched).
    static func cacheCover(bookId: Int, api: APIClient) async {
        guard let data = await api.coverData(bookId) else { return }
        saveCover(bookId: bookId, data: data)
    }

    // ── Local chapter progress ──

    private static var progressFile: URL { dir().appendingPathComponent("progress.json") }

    private static func readProgress() -> [String: StoredProgress] {
        guard let data = try? Data(contentsOf: progressFile),
              let raw = try? JSONDecoder().decode([String: StoredProgress].self, from: data)
        else { return [:] }
        return raw
    }

    private static func writeProgress(_ progress: [String: StoredProgress]) {
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: progressFile, options: .atomic)
        }
    }

    static func localProgress(chapterId: Int) -> StoredProgress? {
        lock.lock(); defer { lock.unlock() }
        return readProgress()[String(chapterId)]
    }

    static func setLocalProgress(chapterId: Int, position: Double, duration: Double,
                                 isListened: Bool, dirty: Bool) {
        lock.lock(); defer { lock.unlock() }
        var progress = readProgress()
        let existing = progress[String(chapterId)]
        progress[String(chapterId)] = StoredProgress(
            positionSeconds: position,
            durationSeconds: duration > 0 ? duration : (existing?.durationSeconds ?? 0),
            isListened: isListened,
            dirty: dirty)
        writeProgress(progress)
    }

    /// Progress recorded while offline, keyed by chapter id.
    static func dirtyProgress() -> [Int: StoredProgress] {
        lock.lock(); defer { lock.unlock() }
        return Dictionary(uniqueKeysWithValues: readProgress()
            .filter { $0.value.dirty }
            .compactMap { key, value in Int(key).map { ($0, value) } })
    }

    static func clearDirty(chapterId: Int) {
        lock.lock(); defer { lock.unlock() }
        var progress = readProgress()
        progress[String(chapterId)]?.dirty = false
        writeProgress(progress)
    }
}
