import SwiftUI

// The books whose chapters live on this device. Everything here is read off disk, so it
// works with the server unreachable — the way in when the Archive can't load.
struct OfflineLibraryView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var entries: [DownloadedBook] = []
    @State private var totalSize: Int64 = 0

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 0.9)
            VStack(spacing: 14) {
                Text("Local Downloads")
                    .font(Theme.serif(22)).foregroundColor(Theme.brass)
                    .tracking(2)
                    .glowVerdigris()
                    .padding(.vertical, 6)

                Text(entries.isEmpty
                     ? "Nothing downloaded yet."
                     : "\(entries.count) book\(entries.count == 1 ? "" : "s") · \(format(totalSize)) — playable with no connection.")
                    .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
                    .multilineTextAlignment(.center)

                if entries.isEmpty {
                    Spacer()
                    Text("Open a book while connected and use ⬇ All to keep it on this device.")
                        .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(entries) { entry in
                                NavigationLink(value: Route.book(entry.book)) {
                                    row(entry)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Downloads.deleteBook(bookId: entry.book.id)
                                        reload()
                                    } label: {
                                        Label("Delete downloads", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func row(_ entry: DownloadedBook) -> some View {
        let onDisk = Downloads.downloadedCount(bookId: entry.book.id)
        return HStack(spacing: 12) {
            CoverImage(book: entry.book, api: auth.api)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.borderBrass, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.book.title).font(Theme.bodyBold(15)).foregroundColor(Theme.parchment)
                    .lineLimit(2)
                Text(entry.book.author).font(Theme.serif(12)).foregroundColor(Theme.parchmentMid)
                    .lineLimit(1)
                Text("\(onDisk) of \(entry.chapters.count) chapters · \(format(Downloads.size(bookId: entry.book.id)))")
                    .font(Theme.body(11)).foregroundColor(Theme.verdigris)
            }
            Spacer(minLength: 0)
            Text("▶").font(.system(size: 14)).foregroundColor(Theme.brassPale)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .charged()
    }

    private func reload() {
        entries = Downloads.downloadedBooks()
        totalSize = Downloads.totalSize()
    }

    private func format(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// Standalone wrapper for presenting the offline library outside the signed-in
// navigation stack (from the login screen when the server can't be reached).
struct OfflineLibrarySheet: View {
    @EnvironmentObject var auth: AuthStore
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            OfflineLibraryView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .book(let book): BookPlayerView(bookId: book.id)
                    default: EmptyView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { onClose() }.foregroundColor(Theme.brass)
                    }
                }
        }
        .tint(Theme.brass)
        .preferredColorScheme(.dark)
    }
}

// A pill that leads to the offline library. Emphasised (and re-worded) when the
// server is unreachable, since that's when it matters.
struct LocalDownloadsButton: View {
    let serverDown: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("📥").font(.system(size: 13))
            Text(serverDown ? "Server unreachable — Local Downloads" : "Local Downloads")
                .font(Theme.body(13))
                .foregroundColor(serverDown ? Theme.ink : Theme.parchmentMid)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(serverDown ? Theme.brass : Theme.surface2)
        .overlay(Capsule().stroke(serverDown ? Theme.verdigris : Theme.borderBrass, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: serverDown ? Theme.verdigris.opacity(0.5) : .clear, radius: 8)
    }
}
