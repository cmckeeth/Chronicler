import SwiftUI

// A collection page: nav title = collection name, grid of its books (tap → BookPlayerView).
struct CollectionView: View {
    @EnvironmentObject var auth: AuthStore

    let collection: Collection

    @State private var books: [Book] = []
    @State private var loading = true
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ZStack {
            ThemedBackground(intensity: 0.9)
            VStack(spacing: 14) {
                Text(collection.name)
                    .font(Theme.serif(24)).foregroundColor(Theme.brass)
                    .tracking(3)
                    .glowVerdigris()
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 6)

                content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle(collection.name)
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
        } else if books.isEmpty {
            Spacer(); Text("This collection holds no volumes, traveller.")
                .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim); Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(books) { book in
                        BookCardView(book: book, api: auth.api, onFavoriteChanged: { await load() })
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func load() async {
        loading = true; error = nil
        do { books = try await auth.api.collectionBooks(collection.id) }
        catch { self.error = "unreachable" }
        loading = false
    }
}
