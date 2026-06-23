import SwiftUI
import AVKit
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
    // Download state per chapter: 0 = none, 1 = downloading, 2 = downloaded.
    @State private var downloads: [Int: Int] = [:]

    private var api: APIClient { auth.api }

    var body: some View {
        ZStack {
            // Tesla glass/grid backdrop always; lightning crackle only during playback.
            if audio.isPlaying {
                ThemedBackground(intensity: 0.9)
            } else {
                Theme.bg.ignoresSafeArea()
                if Theme.mode == .tesla {
                    RadialGradient(colors: [Theme.verdigris.opacity(0.16), Theme.bg2.opacity(0.0)],
                                   center: .center, startRadius: 0, endRadius: 520)
                        .ignoresSafeArea()
                }
            }
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
            HStack {
                Text("Chapters").font(Theme.serif(16)).foregroundColor(Theme.verdigris)
                    .glowVerdigris()
                Spacer()
                downloadAllControl
            }
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
                    // Offline-download indicator.
                    downloadGlyph(chapter.id)
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
                    if downloads[chapter.id] == 2 {
                        Button { removeDownload(chapter) } label: {
                            Label("Remove download", systemImage: "trash")
                        }
                    } else if downloads[chapter.id] != 1 {
                        Button { downloadChapter(chapter) } label: {
                            Label("Download for offline", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var downloadAllControl: some View {
        let allDownloaded = !chapters.isEmpty && chapters.allSatisfy { downloads[$0.id] == 2 }
        let anyDownloading = chapters.contains { downloads[$0.id] == 1 }
        if anyDownloading {
            Text("⚙ Downloading…").font(Theme.body(12)).foregroundColor(Theme.brass)
        } else if allDownloaded {
            Button { removeAll() } label: {
                Text("✕ Remove all").font(Theme.body(12)).foregroundColor(Theme.parchmentDim)
            }
        } else {
            Button { downloadAll() } label: {
                Text("⬇ All").font(Theme.body(12)).foregroundColor(Theme.verdigris)
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

    @ViewBuilder
    private func downloadGlyph(_ chapterId: Int) -> some View {
        switch downloads[chapterId] {
        case 1: Text("⏳").font(.system(size: 13)).foregroundColor(Theme.brass)
        case 2: Text("⬇").font(.system(size: 14)).foregroundColor(Theme.verdigris).glowVerdigris()
        default: EmptyView()
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
                metaField("Title", text: $editTitle)
                metaField("Author", text: $editAuthor)
                metaField("Narrator (optional)", text: $editNarrator)
                metaField("Year (optional)", text: $editYear, keyboard: .numberPad)
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(pendingCover == nil ? "Choose Cover Image" : "📎 Cover selected")
                        .foregroundColor(Theme.brassLight)
                }
                .listRowBackground(Theme.surface2)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .presentationBackground(Theme.surface)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Details").font(Theme.serif(18)).foregroundColor(Theme.brass)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMeta = false }.tint(Theme.parchmentMid)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(savingMeta ? "Saving…" : "Save") { Task { await saveMeta() } }
                        .disabled(savingMeta).tint(Theme.brassLight)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { pendingCover = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }

    // Solid, high-contrast field rows so text is readable in every theme.
    private func metaField(_ placeholder: String, text: Binding<String>,
                           keyboard: UIKeyboardType = .default) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(Theme.parchmentDim))
            .keyboardType(keyboard)
            .foregroundColor(Theme.parchment)
            .tint(Theme.brass)
            .listRowBackground(Theme.surface2)
    }

    // ── Data / actions ──
    private func loadAll() async {
        audio.onProgress = { pos in Task { await saveChapterProgress(pos) } }
        audio.onEnded = { advanceChapter() }
        audio.setBoost(auth.volumeBoosted)
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
        // Seed download indicators from disk.
        for c in chapters { downloads[c.id] = Downloads.isDownloaded(chapterId: c.id) ? 2 : 0 }

        if chapters.isEmpty { return }
        // Resume at the FIRST chapter that isn't completed (earliest unfinished); else first.
        let idx = progresses.firstIndex { !$0.isListened } ?? 0
        loadChapter(chapters[idx], startPosition: progresses[idx].positionSeconds)
    }

    private func loadChapter(_ chapter: Chapter, startPosition: Double) {
        current = chapter
        // Play the local file when downloaded; otherwise stream.
        let source = Downloads.sourceURL(chapterId: chapter.id,
                                         streamURL: api.audioURL(chapterId: chapter.id))
        audio.load(url: source, title: chapter.title, startPosition: startPosition, token: api.token)
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

    // ── Downloads ──
    private func downloadChapter(_ chapter: Chapter) {
        downloads[chapter.id] = 1
        Task {
            let ok = await Downloads.download(chapterId: chapter.id,
                                              url: api.audioURL(chapterId: chapter.id), token: api.token)
            downloads[chapter.id] = ok ? 2 : 0
        }
    }

    private func removeDownload(_ chapter: Chapter) {
        Downloads.deleteChapter(chapterId: chapter.id)
        downloads[chapter.id] = 0
    }

    private func downloadAll() {
        Task {
            for chapter in chapters {
                if downloads[chapter.id] == 2 { continue }
                downloads[chapter.id] = 1
                let ok = await Downloads.download(chapterId: chapter.id,
                                                  url: api.audioURL(chapterId: chapter.id), token: api.token)
                downloads[chapter.id] = ok ? 2 : 0
            }
        }
    }

    private func removeAll() { chapters.forEach { removeDownload($0) } }

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
            content.charged()   // every chapter row stays a little charged
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
                // AirPlay route picker (iOS equivalent of Android's cast button).
                AirPlayButton().frame(width: 32, height: 32)
            }

            // Source badge: 📱 Local / 📡 AirPlay / 📡 Streaming.
            sourceBadge

            // Centered controls: skip-back / electric orb / skip-forward. Speed/autoplay/boost
            // live in the long-press playback dialog (no inline speed control).
            HStack(spacing: 28) {
                Button { audio.skipBack() } label: {
                    Text("⏮30").font(.system(size: 20)).foregroundColor(Theme.brass)
                }
                ElectricButton(isPlaying: audio.isPlaying,
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

    @ViewBuilder
    private var sourceBadge: some View {
        let (text, color, glow): (String, Color, Bool) = {
            if audio.isAirPlay { return ("📡 AirPlay", Theme.verdigris, true) }
            if audio.isLocal   { return ("📱 Local", Theme.verdigris, true) }
            return ("📡 Streaming", Theme.brass, false)
        }()
        HStack {
            Text(text).font(Theme.body(11)).foregroundColor(color).glowIf(glow)
            Spacer()
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
            Toggle(isOn: Binding(get: { auth.volumeBoosted },
                                 set: { auth.setVolumeBoost($0); audio.setBoost($0) })) {
                Text("Volume boost")
                    .font(Theme.body(14)).foregroundColor(Theme.parchment)
            }
            .tint(Theme.verdigris)
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

// AirPlay route picker wrapped for SwiftUI, tinted to theme.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = UIColor(Theme.brass)
        v.activeTintColor = UIColor(Theme.verdigris)
        v.backgroundColor = .clear
        v.prioritizesVideoDevices = false
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// A dark electric orb play/pause button: pulsing verdigris core, crackling forking veins of
// electricity (more/brighter while playing, a faint few when paused), and a glowing pulsing rim.
// No cog — pure electricity. Tap = play/pause, long-press = playback dialog. Mirrors Android's
// drawElectricButton + drawVein. Uses TimelineView(.animation) for the time phase.
struct ElectricButton: View {
    let isPlaying: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                drawOrb(ctx: ctx, size: size, glow: pulse(t), playing: isPlaying)
            }
            // Elaborate pulse: concentric ripples radiating out past the rim — a larger,
            // un-clipped canvas overlaid on the orb.
            .overlay {
                Canvas { ctx, size in
                    drawPulses(ctx: ctx, size: size, t: t, glow: pulse(t), playing: isPlaying)
                }
                .frame(width: 240, height: 240)
                .blendMode(.screen)
                .allowsHitTesting(false)
            }
            .overlay {
                GeometryReader { geo in
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: geo.size.width * 0.30, weight: .bold))
                        .foregroundColor(Theme.brassPale)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .contentShape(Circle())
        .shadow(color: Theme.verdigris.opacity(0.6), radius: 18)
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }

    // Pulsing 0.45…1.0; livelier while playing.
    private func pulse(_ t: Double) -> Double {
        let period = isPlaying ? 1.3 : 3.2
        let phase = t.truncatingRemainder(dividingBy: period) / period
        return 0.45 + 0.55 * (0.5 - 0.5 * cos(phase * 2 * .pi))
    }

    private func drawOrb(ctx: GraphicsContext, size: CGSize, glow: Double, playing: Bool) {
        let cx = size.width / 2, cy = size.height / 2
        let center = CGPoint(x: cx, y: cy)
        let outer = min(size.width, size.height) / 2
        let r = outer * 0.82
        let baseRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

        // Dark orb base with a faint electric-blue depth.
        ctx.fill(Path(ellipseIn: baseRect), with: .radialGradient(
            Gradient(colors: [Color(hex: 0x0a2a40), Theme.ink]),
            center: center, startRadius: 0, endRadius: r * 1.15))

        // Breathing core glow (hotter while playing).
        let coreA = (playing ? 0.55 : 0.22) * (0.55 + 0.45 * glow)
        let coreR = r * 0.92
        ctx.fill(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)),
                 with: .radialGradient(
                    Gradient(colors: [Theme.verdigris.opacity(coreA), Theme.verdigris.opacity(0)]),
                    center: center, startRadius: 0, endRadius: coreR))

        // Concentric inner rings that breathe in place.
        for i in 1...3 {
            let rr = r * (0.30 * Double(i))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2)),
                       with: .color(Theme.verdigris.opacity((0.10 + 0.24 * glow) / Double(i))),
                       lineWidth: 1.5)
        }

        // Breathing rim — outer halo + crisp ring.
        let haloR = r + outer * 0.08
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - haloR, y: cy - haloR, width: haloR * 2, height: haloR * 2)),
                   with: .color(Theme.verdigris.opacity(0.18 * glow)), lineWidth: outer * 0.05)
        ctx.stroke(Path(ellipseIn: baseRect),
                   with: .color(Theme.verdigris.opacity(playing ? glow : glow * 0.6)),
                   lineWidth: outer * 0.05 * glow + 2)
    }

    // Elaborate pulse — staggered concentric ripples expanding from the rim and fading
    // as they grow, plus a breathing source ring. Faster while playing.
    private func drawPulses(ctx: GraphicsContext, size: CGSize, t: Double, glow: Double, playing: Bool) {
        let cx = size.width / 2, cy = size.height / 2
        let rimR = min(size.width, size.height) * 0.195
        let expand = size.width * 0.26
        let period = playing ? 1.6 : 3.2
        let count = 4
        for k in 0..<count {
            let p = ((t / period) + Double(k) / Double(count)).truncatingRemainder(dividingBy: 1)
            let rr = rimR + p * expand
            let a = (1 - p) * (playing ? 1.0 : 0.5)
            if a < 0.02 { continue }
            let rect = CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2)
            // soft glow ring + crisp bright core ring
            ctx.stroke(Path(ellipseIn: rect),
                       with: .color(Theme.verdigris.opacity(0.30 * a)),
                       lineWidth: 7 * (1 - p) + 2)
            ctx.stroke(Path(ellipseIn: rect),
                       with: .color(Color(hex: 0xc8f0ff).opacity(0.7 * a)),
                       lineWidth: 2)
        }
        // Breathing source ring at the rim.
        let rect = CGRect(x: cx - rimR, y: cy - rimR, width: rimR * 2, height: rimR * 2)
        ctx.stroke(Path(ellipseIn: rect),
                   with: .color(Theme.verdigris.opacity(0.5 * glow)), lineWidth: 3)
    }
}
