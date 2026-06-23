import Foundation

enum APIError: Error { case http(Int), decode, network }

// Swift port of Chronicler.Shared/Services/ApiClient.cs against the same .NET REST API.
final class APIClient: @unchecked Sendable {
    static let baseURL = URL(string: "https://chronicler.mckeeth.app")!

    var token: String?

    private let session = URLSession(configuration: .default)
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()   // camelCase keys match property names directly
        return d
    }()

    private func request(_ path: String, method: String = "GET",
                         body: Encodable? = nil, auth: Bool = true) -> URLRequest {
        var req = URLRequest(url: URL(string: path, relativeTo: APIClient.baseURL)!)
        req.httpMethod = method
        if auth, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(AnyEncodable(body))
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, (200..<300).contains(code)
        else { throw APIError.http((resp as? HTTPURLResponse)?.statusCode ?? -1) }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decode }
    }

    @discardableResult
    private func send(_ req: URLRequest) async throws -> Int {
        let (_, resp) = try await session.data(for: req)
        return (resp as? HTTPURLResponse)?.statusCode ?? -1
    }

    // ── Auth ──
    func login(email: String, password: String) async -> String? {
        try? await send(request("/api/auth/login", method: "POST",
                                 body: ["email": email, "password": password], auth: false),
                        as: TokenResponse.self).token
    }
    func register(email: String, password: String) async -> String? {
        try? await send(request("/api/auth/register", method: "POST",
                                 body: ["email": email, "password": password], auth: false),
                        as: TokenResponse.self).token
    }

    // ── Books ──
    func getBooks(root: Bool = false) async throws -> [Book] {
        try await send(request("/api/books" + (root ? "?root=true" : "")), as: [Book].self)
    }
    func getBook(_ id: Int) async throws -> Book {
        try await send(request("/api/books/\(id)"), as: Book.self)
    }
    func coverURL(_ bookId: Int) -> URL {
        URL(string: "/api/books/\(bookId)/cover", relativeTo: APIClient.baseURL)!
    }
    func coverData(_ bookId: Int) async -> Data? {
        let (data, resp) = (try? await session.data(for: request("/api/books/\(bookId)/cover"))) ?? (nil, nil)
        guard let data, let code = (resp as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(code), data.count >= 100 else { return nil }
        return data
    }
    func audioURL(chapterId: Int) -> URL {
        URL(string: "/api/chapters/\(chapterId)/audio", relativeTo: APIClient.baseURL)!
    }

    // ── Collections ──
    func collections() async throws -> [Collection] {
        try await send(request("/api/collections"), as: [Collection].self)
    }
    func collectionBooks(_ id: Int) async throws -> [Book] {
        try await send(request("/api/collections/\(id)/books"), as: [Book].self)
    }
    func collectionCoverURL(_ id: Int) -> URL {
        URL(string: "/api/collections/\(id)/cover", relativeTo: APIClient.baseURL)!
    }
    func collectionCoverData(_ id: Int) async -> Data? {
        let (data, resp) = (try? await session.data(for: request("/api/collections/\(id)/cover"))) ?? (nil, nil)
        guard let data, let code = (resp as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(code), data.count >= 100 else { return nil }
        return data
    }

    func getChapters(bookId: Int) async throws -> [Chapter] {
        try await send(request("/api/books/\(bookId)/chapters"), as: [Chapter].self)
    }
    func getChapterProgress(_ chapterId: Int) async -> ChapterProgress {
        (try? await send(request("/api/chapters/\(chapterId)/progress"), as: ChapterProgress.self))
            ?? ChapterProgress(positionSeconds: 0, isListened: false)
    }
    func saveChapterProgress(_ chapterId: Int, position: Double, duration: Double) async {
        _ = try? await send(request("/api/chapters/\(chapterId)/progress", method: "PUT",
            body: ["positionSeconds": position, "durationSeconds": duration]))
    }
    func resetChapter(_ chapterId: Int) async {
        _ = try? await send(request("/api/chapters/\(chapterId)/reset", method: "POST"))
    }
    func resetBook(_ bookId: Int) async {
        _ = try? await send(request("/api/books/\(bookId)/reset", method: "POST"))
    }
    func toggleFavorite(_ bookId: Int) async -> Bool {
        (try? await send(request("/api/books/\(bookId)/favorite", method: "POST"),
                         as: FavoriteResult.self).isFavorite) ?? false
    }
    func getBookMeta(_ bookId: Int) async -> BookMeta? {
        try? await send(request("/api/books/\(bookId)/meta"), as: BookMeta.self)
    }
    func saveBookMeta(_ bookId: Int, title: String, author: String,
                      narrator: String?, year: Int?) async -> Bool {
        let code = (try? await send(request("/api/books/\(bookId)/meta", method: "PUT",
            body: MetaBody(title: title, author: author, narrator: narrator,
                           description: nil, year: year)))) ?? -1
        return (200..<300).contains(code)
    }
    func uploadCover(_ bookId: Int, imageData: Data, mime: String) async -> Bool {
        var req = request("/api/books/\(bookId)/cover/upload", method: "PUT")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"cover\"; filename=\"cover.jpg\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = data
        let code = (try? await send(req)) ?? -1
        return (200..<300).contains(code)
    }

    // ── Progress (book-level) ──
    func getProgress(_ bookId: Int) async -> Double {
        (try? await send(request("/api/progress/\(bookId)"), as: ProgressResult.self).positionSeconds) ?? 0
    }
    func saveProgress(_ bookId: Int, positionSeconds: Double) async {
        _ = try? await send(request("/api/progress/\(bookId)", method: "PUT",
            body: ["positionSeconds": positionSeconds]))
    }

    // ── Updates / Diag ──
    func getLatestVersion() async -> String? {
        try? await send(request("/api/update/version", auth: false), as: VersionResult.self).version
    }
    func diag(_ message: String) async {
        _ = try? await send(request("/api/diag", method: "POST", body: ["message": message]))
    }

    private struct TokenResponse: Decodable { let token: String }
    private struct ProgressResult: Decodable { let positionSeconds: Double }
    private struct VersionResult: Decodable { let version: String }
    private struct FavoriteResult: Decodable { let isFavorite: Bool }
    private struct MetaBody: Encodable {
        let title: String; let author: String; let narrator: String?
        let description: String?; let year: Int?
    }
}

// Type-erased Encodable so request bodies can be dictionaries or structs.
struct AnyEncodable: Encodable {
    private let encodeFn: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFn = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFn(encoder) }
}
