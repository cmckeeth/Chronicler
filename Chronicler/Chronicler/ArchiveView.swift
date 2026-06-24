import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var books: [Book] = []
    @State private var collections: [Collection] = []
    @State private var search = ""
    @State private var tab = "books"            // books | collections
    @State private var favOnly = false          // book-level favorite filter (Books tab only)
    @State private var loading = true
    @State private var refreshing = false
    @State private var error: String?

    // Grid density: user-chosen 1/2/3 columns, persisted across launches.
    @AppStorage("gridColumns") private var gridColumns = 3
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumns)
    }

    private var isSearching: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Collections show only on the Collections tab while browsing (never while searching).
    private var showCollections: Bool {
        !isSearching && tab == "collections" && !collections.isEmpty
    }

    var filtered: [Book] {
        // Search is always flat over all books. When browsing:
        //   Books tab       -> every book flat (standalone AND inside collections)
        //   Collections tab -> no books, only collection cards
        var q: [Book]
        if isSearching {
            let s = search.lowercased()
            q = books.filter {
                $0.title.lowercased().contains(s) ||
                $0.author.lowercased().contains(s) ||
                ($0.narrator?.lowercased().contains(s) ?? false)
            }
        } else {
            q = tab == "collections" ? [] : books
        }
        if favOnly { q = q.filter { $0.isFavorite } }
        q.sort { $0.title.lowercased() < $1.title.lowercased() }
        return q
    }

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 0.9)
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

                chipGroup("", [("Books","books"),("Collections","collections")],
                          selection: $tab)
                if tab == "books" {
                    favChip
                }
                layoutChips

                content

                HStack {
                    UpdateBanner(api: auth.api)
                    Spacer()
                    refreshButton
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // Reload when crossing the search/browse boundary (root+collections vs flat books).
        .onChange(of: isSearching) { Task { await load() } }
    }

    @ViewBuilder private var content: some View {
        if loading {
            Spacer(); Text("Consulting the archive...")
                .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim); Spacer()
        } else if let error {
            Spacer(); Text("The pneumatic tubes have failed: \(error)")
                .font(Theme.body(14)).foregroundColor(Theme.rust)
                .multilineTextAlignment(.center); Spacer()
        } else if filtered.isEmpty && !showCollections {
            Spacer(); Text(books.isEmpty && collections.isEmpty
                            ? "The archive lies empty, traveller."
                            : "No volumes match this filter.")
                .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim); Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    if showCollections {
                        ForEach(collections) { collection in
                            CollectionCardView(collection: collection, api: auth.api)
                        }
                    }
                    ForEach(filtered) { book in
                        BookCardView(book: book, api: auth.api, onFavoriteChanged: { await load() })
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await refresh() }
        } label: {
            HStack(spacing: 6) {
                if refreshing {
                    ProgressView().tint(Theme.ink).scaleEffect(0.7)
                } else {
                    Text("↻").font(Theme.serif(14))
                }
                Text(refreshing ? "Refreshing…" : "Refresh")
            }
            .font(Theme.body(13))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 18).padding(.vertical, 7)
            .background(Theme.brass)
            .overlay(Capsule().stroke(Theme.verdigris, lineWidth: 1))
            .clipShape(Capsule())
            .shadow(color: Theme.verdigris.opacity(0.5), radius: 6)
        }
        .disabled(refreshing)
    }

    // Single on/off favorites toggle (no "All" chip), shown only on the Books tab.
    private var favChip: some View {
        HStack(spacing: 6) {
            Button { favOnly.toggle() } label: {
                Text("★ Favorites").font(Theme.body(12))
                    .foregroundColor(favOnly ? Theme.ink : Theme.parchmentMid)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(favOnly ? Theme.brass : Theme.surface2)
                    .overlay(Capsule().stroke(favOnly ? Theme.verdigris : .clear, lineWidth: 1))
                    .clipShape(Capsule())
                    .shadow(color: favOnly ? Theme.verdigris.opacity(0.5) : .clear, radius: 8)
            }
            Spacer()
        }
    }

    // Grid density picker: 1 / 2 / 3 columns, persisted via @AppStorage.
    private var layoutChips: some View {
        HStack(spacing: 6) {
            Text("Grid").font(Theme.body(11)).foregroundColor(Theme.parchmentDim)
            ForEach([1, 2, 3], id: \.self) { n in
                let active = gridColumns == n
                Button { gridColumns = n } label: {
                    Text("\(n)").font(Theme.body(12))
                        .foregroundColor(active ? Theme.ink : Theme.parchmentMid)
                        .frame(minWidth: 14)
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

    private func chipGroup(_ label: String, _ options: [(String, String)],
                           selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            if !label.isEmpty {
                Text(label).font(Theme.body(11)).foregroundColor(Theme.parchmentDim)
            }
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

    // Browse view: ALL books + collections loaded; chips slice them client-side
    // (All = root books + collections, Books = all books flat, Collections = collections only).
    // Search view: all books flat, so books inside collections are findable.
    private func load() async {
        loading = true; error = nil
        do {
            if isSearching {
                books = try await auth.api.getBooks()
                collections = []
            } else {
                async let b = auth.api.getBooks()
                async let c = auth.api.collections()
                books = try await b
                collections = (try? await c) ?? []
            }
        } catch { self.error = "unreachable" }
        loading = false
    }

    // Reload without blanking the grid — keeps current content visible while fetching.
    private func refresh() async {
        refreshing = true
        do {
            if isSearching {
                books = try await auth.api.getBooks()
                collections = []
            } else {
                async let b = auth.api.getBooks()
                async let c = auth.api.collections()
                books = try await b
                collections = (try? await c) ?? []
            }
            error = nil
        } catch { self.error = "unreachable" }
        refreshing = false
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

// A collection reads as a folder/stack of volumes with a "N books" badge.
struct CollectionCardView: View {
    let collection: Collection
    let api: APIClient

    var body: some View {
        NavigationLink(value: Route.collection(collection)) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Stacked sheets peeking out behind the cover sell the "folder" look.
                    ZStack {
                        Rectangle().fill(Theme.surface2)
                            .frame(height: 150).frame(maxWidth: .infinity)
                            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                            .offset(x: 6, y: 6)
                        Rectangle().fill(Theme.surface2)
                            .frame(height: 150).frame(maxWidth: .infinity)
                            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                            .offset(x: 3, y: 3)
                        CollectionCoverImage(collection: collection, api: api)
                            .frame(height: 150).frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    }
                    Text("\(collection.bookCount) book\(collection.bookCount == 1 ? "" : "s")")
                        .font(Theme.body(11)).foregroundColor(Theme.ink)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.brass)
                        .overlay(Capsule().stroke(Theme.verdigris, lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(6)
                }
                Text(collection.name).font(Theme.body(14)).foregroundColor(Theme.parchment)
                    .lineLimit(2)
                Text("Collection").font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
                    .lineLimit(1)
            }
            .padding(10)
            .electricPanel(bg: Theme.surface, corner: 4, alpha: 0.6, glowRadius: 12)
        }
        .buttonStyle(.plain)
    }
}
