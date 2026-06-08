import SwiftUI
import PhotosUI

struct BookPlayerView: View {
    let bookId: Int
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio = AudioPlayerModel()

    @State private var book: Book?
    @State private var chapters: [Chapter] = []
    @State private var progresses: [ChapterProgress] = []
    @State private var current: Chapter?
    @State private var showMeta = false

    private var api: APIClient { auth.api }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if book == nil {
                Text("Consulting the archive...")
                    .font(Theme.serif(15)).foregroundColor(Theme.parchmentDim)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        header
                        if current != nil { AudioPlayerView(audio: audio) }
                        chapterList
                        Divider().background(Theme.border)
                        Button("⚙ Reset All Progress") { Task { await resetBook() } }
                            .font(Theme.body(12)).foregroundColor(Theme.parchmentDim).opacity(0.5)
                            .padding(.bottom, 12)
                    }
                    .padding(12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("‹ Library") { dismiss() }.foregroundColor(Theme.brass)
            }
        }
        .task { await loadAll() }
        .onDisappear { audio.teardown() }
        .sheet(isPresented: $showMeta) { metaEditor }
    }

    // ── Header (cover + title/author) ──
    private var header: some View {
        VStack(spacing: 8) {
            if let book {
                CoverImage(book: book, api: api)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.borderBrass, lineWidth: 1))
                    .onLongPressGesture(minimumDuration: 0.6) { Task { await openMeta() } }
                Text(book.title).font(Theme.display(20)).foregroundColor(Theme.parchment)
                    .multilineTextAlignment(.center)
                HStack(spacing: 0) {
                    Text(book.author).font(Theme.serif(14)).foregroundColor(Theme.parchmentMid)
                    if let n = book.narrator {
                        Text(" · \(n)").font(Theme.serif(14)).foregroundColor(Theme.parchmentDim)
                    }
                }
            }
        }
    }

    // ── Chapter list ──
    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chapters").font(Theme.serif(16)).foregroundColor(Theme.brass)
            ForEach(Array(zip(chapters, progresses).enumerated()), id: \.element.0.id) { _, pair in
                let (chapter, progress) = pair
                let isCurrent = chapter.id == current?.id
                HStack(spacing: 8) {
                    Text("\(chapter.trackNumber)")
                        .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
                        .frame(width: 24)
                    Text(chapter.title).font(Theme.body(14))
                        .foregroundColor(progress.isListened ? Theme.parchmentDim : Theme.parchment)
                        .strikethrough(progress.isListened)
                    Spacer()
                    if progress.isListened {
                        Text("✓").foregroundColor(Theme.verdigris)
                    } else if progress.positionSeconds > 0 {
                        Text("…").foregroundColor(Theme.brass)
                    }
                    if isCurrent { Text("▶").foregroundColor(Theme.brassPale) }
                    Button("↺") { Task { await resetChapter(chapter.id) } }
                        .foregroundColor(Theme.parchmentDim).opacity(0.6)
                }
                .padding(.vertical, 8).padding(.horizontal, 8)
                .background(isCurrent ? Theme.surface2 : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .contentShape(Rectangle())
                .onTapGesture { selectChapter(chapter) }
            }
        }
    }

    // ── Meta editor sheet ──
    @State private var editTitle = ""
    @State private var editAuthor = ""
    @State private var editNarrator = ""
    @State private var editYear = ""
    @State private var savingMeta = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingCover: Data?

    private var metaEditor: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $editTitle)
                TextField("Author", text: $editAuthor)
                TextField("Narrator (optional)", text: $editNarrator)
                TextField("Year (optional)", text: $editYear).keyboardType(.numberPad)
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(pendingCover == nil ? "Choose Cover Image" : "📎 Cover selected")
                }
            }
            .navigationTitle("Edit Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showMeta = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(savingMeta ? "Saving…" : "Save") { Task { await saveMeta() } }
                        .disabled(savingMeta)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { pendingCover = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    // ── Data / actions ──
    private func loadAll() async {
        audio.onProgress = { pos in Task { await saveChapterProgress(pos) } }
        audio.onEnded = { advanceChapter() }
        book = try? await api.getBook(bookId)
        guard book != nil else { return }
        chapters = (try? await api.getChapters(bookId: bookId)) ?? []
        var progs: [ChapterProgress] = []
        for c in chapters { progs.append(await api.getChapterProgress(c.id)) }
        progresses = progs

        var idx = progresses.firstIndex { !$0.isListened && $0.positionSeconds > 0 }
            ?? progresses.firstIndex { !$0.isListened } ?? 0
        if chapters.isEmpty { return }
        idx = min(idx, chapters.count - 1)
        loadChapter(chapters[idx], startPosition: progresses[idx].positionSeconds)
    }

    private func loadChapter(_ chapter: Chapter, startPosition: Double) {
        current = chapter
        audio.load(url: api.audioURL(chapterId: chapter.id),
                   title: chapter.title, startPosition: startPosition, token: api.token)
    }

    private func selectChapter(_ chapter: Chapter) {
        let idx = chapters.firstIndex { $0.id == chapter.id } ?? 0
        loadChapter(chapter, startPosition: progresses[idx].positionSeconds)
    }

    private func advanceChapter() {
        guard let cur = current,
              let idx = chapters.firstIndex(where: { $0.id == cur.id }),
              idx < chapters.count - 1 else { return }
        progresses[idx].isListened = true
        loadChapter(chapters[idx + 1], startPosition: 0)
    }

    private func saveChapterProgress(_ position: Double) async {
        guard let cur = current else { return }
        await api.saveChapterProgress(cur.id, position: position, duration: 0)
        if let idx = chapters.firstIndex(where: { $0.id == cur.id }) {
            progresses[idx].positionSeconds = position
        }
    }

    private func resetChapter(_ id: Int) async {
        await api.resetChapter(id)
        if let idx = chapters.firstIndex(where: { $0.id == id }) {
            progresses[idx] = ChapterProgress(positionSeconds: 0, isListened: false)
        }
    }

    private func resetBook() async {
        await api.resetBook(bookId)
        progresses = progresses.map { _ in ChapterProgress(positionSeconds: 0, isListened: false) }
    }

    private func openMeta() async {
        let meta = await api.getBookMeta(bookId)
        editTitle = meta?.title ?? book?.title ?? ""
        editAuthor = meta?.author ?? book?.author ?? ""
        editNarrator = meta?.narrator ?? book?.narrator ?? ""
        editYear = (meta?.year ?? book?.year).map(String.init) ?? ""
        pendingCover = nil; pickerItem = nil
        showMeta = true
    }

    private func saveMeta() async {
        savingMeta = true
        _ = await api.saveBookMeta(bookId, title: editTitle, author: editAuthor,
                                   narrator: editNarrator.isEmpty ? nil : editNarrator,
                                   year: Int(editYear))
        if let pendingCover {
            _ = await api.uploadCover(bookId, imageData: pendingCover, mime: "image/jpeg")
            await CoverCache.shared.invalidate(bookId)
        }
        book = try? await api.getBook(bookId)
        savingMeta = false
        showMeta = false
    }
}

// ── Audio player UI (mirrors AudioPlayer.razor controls) ──
struct AudioPlayerView: View {
    @ObservedObject var audio: AudioPlayerModel
    @State private var showSpeed = false
    private let speeds = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(audio.title).font(Theme.serif(14)).foregroundColor(Theme.parchment)
                    .lineLimit(1)
                Spacer()
                Text(audio.duration > 0
                     ? "\(formatTime(audio.currentPosition)) / \(formatTime(audio.duration))"
                     : formatTime(audio.currentPosition))
                    .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            }

            HStack(spacing: 24) {
                Button { audio.skipBack() } label: { Text("⏮30").font(Theme.body(16)) }
                Button { audio.togglePlay() } label: {
                    Text(audio.isPlaying ? "⏸" : "▶").font(.system(size: 30))
                }
                Button { audio.skipForward() } label: { Text("30⏭").font(Theme.body(16)) }
                Text("\(speedLabel)×")
                    .font(Theme.body(14)).foregroundColor(Theme.parchmentMid)
                    .onLongPressGesture(minimumDuration: 0.6) { showSpeed = true }
            }
            .foregroundColor(Theme.brass)

            if audio.duration > 0 {
                Slider(value: Binding(
                    get: { audio.currentPosition },
                    set: { audio.seek(to: $0) }), in: 0...audio.duration)
                    .tint(Theme.brass)
            }
        }
        .padding(12)
        .background(Theme.surface.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .confirmationDialog("Speed", isPresented: $showSpeed, titleVisibility: .visible) {
            ForEach(speeds, id: \.self) { s in
                Button("\(speedText(s))×") { audio.setSpeed(s) }
            }
        }
    }

    private var speedLabel: String { speedText(audio.speed) }
    private func speedText(_ s: Double) -> String {
        s == s.rounded() ? String(Int(s)) : String(s)
    }
}
