import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var books: [Book] = []
    @State private var search = ""
    @State private var sort = "name"
    @State private var filter = "favorites"     // default matches LibraryBrowser
    @State private var loading = true
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var filtered: [Book] {
        var q = books
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let s = search.lowercased()
            q = q.filter {
                $0.title.lowercased().contains(s) ||
                $0.author.lowercased().contains(s) ||
                ($0.narrator?.lowercased().contains(s) ?? false)
            }
        }
        switch filter {
        case "inprogress": q = q.filter { $0.isInProgress }
        case "favorites":  q = q.filter { $0.isFavorite }
        default: break
        }
        switch sort {
        case "date": q.sort { $0.addedAt > $1.addedAt }
        case "progress":
            q.sort {
                if $0.isInProgress != $1.isInProgress { return $0.isInProgress }
                if $0.isCompleted != $1.isCompleted { return $0.isCompleted }
                return $0.title < $1.title
            }
        default: q.sort { $0.title.lowercased() < $1.title.lowercased() }
        }
        return q
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                // Cinzel (serif), NOT Cinzel Decorative; verdigris electric glow.
                Text("The Archive")
                    .font(Theme.serif(24)).foregroundColor(Theme.brass)
                    .tracking(3)
                    .glowVerdigris()
                    .padding(.vertical, 6)

                HStack(spacing: 8) {
                    TextField("Query the archive...", text: $search)
                        .font(Theme.body(14)).foregroundColor(Theme.parchment)
                        .tint(Theme.verdigris)            // verdigris cursor
                        .padding(8)
                        .background(Theme.surface2)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.verdigris.opacity(0.4), lineWidth: 1))
                }

                chipGroup("Sort", [("Name","name"),("Added","date"),("Progress","progress")],
                          selection: $sort)
                chipGroup("Show", [("All","all"),("In Progress","inprogress"),("★ Favorites","favorites")],
                          selection: $filter)

                content

                UpdateBanner(api: auth.api).padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        if loading {
            Spacer(); Text("Consulting the archive...")
                .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim); Spacer()
        } else if let error {
            Spacer(); Text("The pneumatic tubes have failed: \(error)")
                .font(Theme.body(14)).foregroundColor(Theme.rust)
                .multilineTextAlignment(.center); Spacer()
        } else if filtered.isEmpty {
            Spacer(); Text(books.isEmpty ? "The archive lies empty, traveller."
                                         : "No volumes match this filter.")
                .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim); Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { book in
                        BookCardView(book: book, api: auth.api, onFavoriteChanged: { await load() })
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func chipGroup(_ label: String, _ options: [(String, String)],
                           selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label).font(Theme.body(11)).foregroundColor(Theme.parchmentDim)
            ForEach(options, id: \.1) { (title, value) in
                let active = selection.wrappedValue == value
                Button { selection.wrappedValue = value } label: {
                    Text(title).font(Theme.body(12))
                        .foregroundColor(active ? Theme.ink : Theme.parchmentMid)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(active ? Theme.brass : Theme.surface2)
                        .overlay(Capsule().stroke(active ? Theme.verdigris : .clear, lineWidth: 1))
                        .clipShape(Capsule())
                        .shadow(color: active ? Theme.verdigris.opacity(0.5) : .clear, radius: 8)
                }
            }
            Spacer()
        }
    }

    private func load() async {
        loading = true; error = nil
        do { books = try await auth.api.getBooks() }
        catch { self.error = "unreachable" }
        loading = false
    }
}

struct BookCardView: View {
    let book: Book
    let api: APIClient
    let onFavoriteChanged: () async -> Void

    @State private var isFavorite: Bool
    @State private var showMenu = false

    init(book: Book, api: APIClient, onFavoriteChanged: @escaping () async -> Void) {
        self.book = book; self.api = api; self.onFavoriteChanged = onFavoriteChanged
        _isFavorite = State(initialValue: book.isFavorite)
    }

    var body: some View {
        NavigationLink(value: Route.book(book)) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    CoverImage(book: book, api: api)
                        .frame(height: 150).frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    if isFavorite {
                        Text("★").font(.system(size: 18)).foregroundColor(Theme.brassPale)
                            .padding(4)
                    }
                }
                Text(book.title).font(Theme.body(14)).foregroundColor(Theme.parchment)
                    .lineLimit(2)
                Text(book.author).font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
                    .lineLimit(1)
                if let narrator = book.narrator {
                    Text(narrator).font(Theme.body(11)).foregroundColor(Theme.parchmentDim).opacity(0.7)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .electricPanel(bg: Theme.surface, corner: 4,
                           alpha: isFavorite ? 0.9 : 0.5,
                           glowRadius: isFavorite ? 18 : 10)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.6) { showMenu = true }
        .confirmationDialog(book.title, isPresented: $showMenu, titleVisibility: .visible) {
            Button(isFavorite ? "★ Remove from Favorites" : "☆ Add to Favorites") {
                toggleFavorite()
            }
        }
    }

    private func toggleFavorite() {
        isFavorite.toggle()
        Task {
            _ = await api.toggleFavorite(book.id)
            await onFavoriteChanged()
        }
    }
}
