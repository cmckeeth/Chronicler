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
                    VStack(spacing: 24) {
                        header
                        if current != nil { AudioPlayerView(audio: audio, auth: auth) }
                        chapterList
                        Divider().background(Theme.border)
                        Button("⚙ Reset All Progress") { Task { await resetBook() } }
                            .font(Theme.body(12)).foregroundColor(Theme.parchmentDim).opacity(0.5)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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
        VStack(spacing: 14) {
            if let book {
                CoverImage(book: book, api: api)
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.borderBrass, lineWidth: 1))
                    .onLongPressGesture(minimumDuration: 0.6) { Task { await openMeta() } }
                // Book title is Lora bold (matches the Archive list), NOT Cinzel Decorative.
                Text(book.title).font(Theme.bodyBold(20)).foregroundColor(Theme.parchment)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Chapters").font(Theme.serif(16)).foregroundColor(Theme.verdigris)
                .glowVerdigris()
            ForEach(Array(zip(chapters, progresses).enumerated()), id: \.element.0.id) { _, pair in
                let (chapter, progress) = pair
                let isCurrent = chapter.id == current?.id
                HStack(spacing: 8) {
                    Text("\(chapter.trackNumber)")
                        .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
                        .frame(width: 28)
                    Text(chapter.title).font(Theme.body(14))
                        .foregroundColor(progress.isListened ? Theme.parchmentDim : Theme.parchment)
                        .strikethrough(progress.isListened)
                    Spacer()
                    // Always-visible status: ✓ finished, ◐ in progress, ○ not started.
                    statusGlyph(progress)
                    if isCurrent { Text("▶").font(.system(size: 14)).foregroundColor(Theme.brassPale) }
                }
                .padding(.vertical, 14).padding(.horizontal, 12)
                .modifier(ChapterRowBackground(isCurrent: isCurrent))
                .contentShape(Rectangle())
                .onTapGesture { selectChapter(chapter) }
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await resetChapter(chapter.id) }
                    } label: {
                        Label("Reset chapter", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusGlyph(_ progress: ChapterProgress) -> some View {
        if progress.isListened {
            Text("✓").font(.system(size: 18)).foregroundColor(Theme.verdigris).glowVerdigris()
        } else if progress.positionSeconds > 0 {
            Text("◐").font(.system(size: 18)).foregroundColor(Theme.brass)
        } else {
            Text("○").font(.system(size: 18)).foregroundColor(Theme.parchmentDim.opacity(0.5))
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
        // Load all chapter statuses in PARALLEL so they show immediately on open.
        progresses = await withTaskGroup(of: (Int, ChapterProgress).self) { group in
            for (i, c) in chapters.enumerated() {
                group.addTask { (i, await api.getChapterProgress(c.id)) }
            }
            var result = Array(repeating: ChapterProgress(positionSeconds: 0, isListened: false),
                               count: chapters.count)
            for await (i, p) in group { result[i] = p }
            return result
        }

        if chapters.isEmpty { return }
        // Resume at the FIRST chapter that isn't completed (earliest unfinished); else first.
        let idx = progresses.firstIndex { !$0.isListened } ?? 0
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
        if auth.autoplayNext { audio.play() }   // continue into the next chapter
    }

    private func saveChapterProgress(_ position: Double) async {
        guard let cur = current else { return }
        let duration = audio.duration
        await api.saveChapterProgress(cur.id, position: position, duration: duration)  // send real duration so server marks finished
        if let idx = chapters.firstIndex(where: { $0.id == cur.id }) {
            progresses[idx].positionSeconds = position
            if duration > 0 && position / duration >= 0.95 {                            // 95% = finished
                progresses[idx].isListened = true
            }
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

// Applies the electricPanel only to the current chapter row.
private struct ChapterRowBackground: ViewModifier {
    let isCurrent: Bool
    func body(content: Content) -> some View {
        if isCurrent {
            content.electricPanel(bg: Theme.surface2, corner: 4, alpha: 0.8, glowRadius: 8)
        } else {
            content
        }
    }
}

// ── Audio player UI (mirrors AudioPlayer.razor + Android AudioPlayerBar) ──
struct AudioPlayerView: View {
    @ObservedObject var audio: AudioPlayerModel
    @ObservedObject var auth: AuthStore
    @State private var showPlayback = false
    private let speeds = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(audio.title).font(Theme.body(14)).foregroundColor(Theme.parchment)
                    .lineLimit(1)
                Spacer()
                Text(audio.duration > 0
                     ? "\(formatTime(audio.currentPosition)) / \(formatTime(audio.duration))"
                     : formatTime(audio.currentPosition))
                    .font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            }

            // Centered controls: skip-back / gear / skip-forward. Speed/autoplay live in
            // the long-press playback dialog (no inline speed control).
            HStack(spacing: 28) {
                Button { audio.skipBack() } label: {
                    Text("⏮30").font(.system(size: 20)).foregroundColor(Theme.brass)
                }
                GearButton(isPlaying: audio.isPlaying,
                           onTap: { audio.togglePlay() },
                           onLongPress: { showPlayback = true })
                    .frame(width: 104, height: 104)
                Button { audio.skipForward() } label: {
                    Text("30⏭").font(.system(size: 20)).foregroundColor(Theme.brass)
                }
            }
            .padding(.vertical, 8)

            if audio.duration > 0 {
                Slider(value: Binding(
                    get: { audio.currentPosition },
                    set: { audio.seek(to: $0) }), in: 0...audio.duration)
                    .tint(Theme.brass)
            }
        }
        .padding(14)
        .electricPanel(bg: Theme.surface, corner: 6, alpha: 0.7, glowRadius: 18)
        .sheet(isPresented: $showPlayback) {
            playbackSheet
                .presentationDetents([.medium])
                .presentationBackground(Theme.surface)
        }
    }

    private var playbackSheet: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Playback").font(Theme.serif(20)).foregroundColor(Theme.verdigris)
                .glowVerdigris()
                .padding(.bottom, 4)
            Text("Speed").font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            ForEach(speeds, id: \.self) { s in
                let selected = abs(audio.speed - s) < 0.01
                Button { audio.setSpeed(s); showPlayback = false } label: {
                    Text("\(speedText(s))×")
                        .font(Theme.body(18)).fontWeight(selected ? .bold : .regular)
                        .foregroundColor(selected ? Theme.brassPale : Theme.parchmentMid)
                        .glowIf(selected)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
            Toggle(isOn: Binding(get: { auth.autoplayNext },
                                 set: { auth.setAutoplay($0) })) {
                Text("Autoplay next chapter")
                    .font(Theme.body(14)).foregroundColor(Theme.parchment)
            }
            .tint(Theme.verdigris)
            .padding(.top, 8)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speedText(_ s: Double) -> String {
        s == s.rounded() ? String(Int(s)) : String(s)
    }
}

private extension View {
    @ViewBuilder func glowIf(_ on: Bool) -> some View {
        if on { self.glowVerdigris() } else { self }
    }
}

// Steampunk brass-gear play/pause button. Tap = play/pause, long-press = playback dialog.
// The gear spins (~40°/s) while playing and freezes at its angle when paused; a verdigris
// electric ring pulses around the rim. Mirrors Android drawGearButton + rotation effect.
struct GearButton: View {
    let isPlaying: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    // Persisted rotation: angle accumulated up to the last pause, plus live elapsed
    // playing-time. Folded together on pause so it freezes at the current angle.
    @State private var baseAngle: Double = 0
    @State private var playStart: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            Canvas { ctx, size in
                drawGear(ctx: ctx, size: size, angle: currentAngle(now), glow: pulse(now))
            }
            .overlay {
                // Centered play/pause SF Symbol, ink-colored, large for driving.
                GeometryReader { geo in
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: geo.size.width * 0.32, weight: .bold))
                        .foregroundColor(Theme.ink)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .contentShape(Circle())
        .shadow(color: Theme.verdigris.opacity(0.6), radius: 18)
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                playStart = Date()
            } else {
                // Freeze: fold elapsed spin into the base angle.
                baseAngle = currentAngle(Date())
                playStart = nil
            }
        }
        .onAppear { if isPlaying { playStart = Date() } }
    }

    // Angle = frozen base + (seconds spent playing since last resume) * 40°/s.
    private func currentAngle(_ now: Date) -> Double {
        guard isPlaying, let start = playStart else { return baseAngle }
        return (baseAngle + now.timeIntervalSince(start) * 40).truncatingRemainder(dividingBy: 360)
    }

    // Pulsing alpha for the electric ring; livelier while playing.
    private func pulse(_ now: Date) -> Double {
        let period = isPlaying ? 1.3 : 3.2
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return 0.45 + 0.55 * (0.5 - 0.5 * cos(phase * 2 * .pi))
    }

    private func drawGear(ctx: GraphicsContext, size: CGSize, angle: Double, glow: Double) {
        let cx = size.width / 2, cy = size.height / 2
        let outer = min(size.width, size.height) / 2
        let rFace = outer * 0.74
        let toothH = outer * 0.24
        let teeth = 10
        // Tooth width == gap width at the pitch radius.
        let pitch = outer - toothH / 2
        let toothW = pitch * (.pi / Double(teeth))
        let toothCorner = outer * 0.03
        let rad = angle * .pi / 180

        // Gear teeth around the rim (rotating).
        for i in 0..<teeth {
            let a = rad + Double(i) * 2 * .pi / Double(teeth)
            var ctx2 = ctx
            ctx2.translateBy(x: cx, y: cy)
            ctx2.rotate(by: .radians(a))
            let rect = CGRect(x: -toothW / 2, y: -outer + 1, width: toothW, height: toothH)
            ctx2.fill(Path(roundedRect: rect, cornerRadius: toothCorner),
                      with: .color(Theme.borderBrass))
        }

        // Brass face with an off-center radial sheen.
        let faceRect = CGRect(x: cx - rFace, y: cy - rFace, width: rFace * 2, height: rFace * 2)
        ctx.fill(Path(ellipseIn: faceRect), with: .radialGradient(
            Gradient(colors: [Theme.brassPale, Theme.brass, Theme.borderBrass]),
            center: CGPoint(x: cx - rFace * 0.3, y: cy - rFace * 0.3),
            startRadius: 0, endRadius: rFace * 1.5))

        // Dark rim line.
        ctx.stroke(Path(ellipseIn: faceRect), with: .color(Theme.ink.opacity(0.4)),
                   lineWidth: outer * 0.04)

        // Rivets (rotating with the gear).
        let rivetRing = rFace * 0.80
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi + rad
            let rc = CGPoint(x: cx + rivetRing * cos(a), y: cy + rivetRing * sin(a))
            let rr = outer * 0.04
            ctx.fill(Path(ellipseIn: CGRect(x: rc.x - rr, y: rc.y - rr, width: rr * 2, height: rr * 2)),
                     with: .color(Theme.ink.opacity(0.5)))
        }

        // Pulsing verdigris electric ring (fixed).
        let ringR = rFace + outer * 0.015
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR,
                                          width: ringR * 2, height: ringR * 2)),
                   with: .color(Theme.verdigris.opacity(glow)),
                   lineWidth: outer * 0.06 * glow + 1)
    }
}
