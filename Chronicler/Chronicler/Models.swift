import Foundation

// Codable mirrors of the C# DTOs (System.Text.Json Web defaults => camelCase keys).

struct Book: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String
    let narrator: String?
    let durationSeconds: Double
    let hasCover: Bool
    let addedAt: String          // ISO-8601; sorts lexically
    var chapterCount: Int = 0
    var listenedCount: Int = 0
    let year: Int?
    var isFavorite: Bool = false

    var isCompleted: Bool { chapterCount > 0 && listenedCount >= chapterCount }
    var isInProgress: Bool { listenedCount > 0 && !isCompleted }
}

struct Chapter: Codable, Identifiable, Hashable {
    let id: Int
    let bookId: Int
    let title: String
    let trackNumber: Int
}

struct ChapterProgress: Codable, Hashable {
    var positionSeconds: Double
    var isListened: Bool
}

struct BookMeta: Codable {
    let id: Int
    let title: String
    let author: String
    let narrator: String?
    let description: String?
    let year: Int?
}

struct Bookmark: Codable, Identifiable, Hashable {
    let id: Int
    let bookId: Int
    let positionSeconds: Double
    let label: String?
    let createdAt: String
}
