import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: WallpaperLibrary
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if library.images.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !library.images.isEmpty {
                settingsBar
            }
        }
        .overlay {
            // 빈 화면은 자체 점선 영역이 반응하므로 목록이 있을 때만 덮는다.
            if isDropTargeted && !library.images.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            library.add(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("폴더 열기", systemImage: "folder", action: library.openFolder)
                    .labelStyle(.titleAndIcon)
                Button("이미지 추가", systemImage: "plus", action: library.addWithPanel)
                    .labelStyle(.titleAndIcon)
            }
        }
        .alert(
            "문제가 생겼어요",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.errorMessage = nil } }
            ),
            presenting: library.errorMessage
        ) { _ in
            Button("확인") {}
        } message: { message in
            Text(message)
        }
    }

    // 안내 문장 대신 점선 영역으로 끌어다 놓는 곳임을 보여 준다.
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            Button("이미지 추가", action: library.addWithPanel)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 2, dash: [10, 6])
                )
        }
        .padding(28)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 24)], spacing: 28) {
                ForEach(library.images, id: \.self) { url in
                    WallpaperCell(url: url)
                }
            }
            .padding(28)
        }
    }

    private var settingsBar: some View {
        HStack(spacing: 32) {
            HStack(spacing: 10) {
                Text("화면 맞춤")
                Picker("화면 맞춤", selection: $library.fitMode) {
                    ForEach(FitMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            HStack(spacing: 10) {
                Text("남는 부분")
                Picker("남는 부분", selection: $library.barColor) {
                    ForEach(BarColor.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            // 꽉 채우기에서는 남는 부분이 없으므로 끈다.
            .disabled(library.fitMode == .fill)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct WallpaperCell: View {
    let url: URL

    @EnvironmentObject private var library: WallpaperLibrary
    @State private var thumbnail: CGImage?
    @State private var isHovering = false
    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var isNameFieldFocused: Bool

    /// 미리보기 비율을 실제 화면 비율에 맞춘다.
    private static let screenRatio: CGFloat = NSScreen.main.map { $0.frame.width / $0.frame.height } ?? 1.6

    private var isCurrent: Bool { library.isCurrent(url) }
    private var name: String { url.deletingPathExtension().lastPathComponent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                library.apply(url)
            } label: {
                preview
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }

            nameRow
                .font(.system(size: 14))
                .frame(height: 24)
        }
        .contextMenu {
            Button("바탕화면으로 적용") { library.apply(url) }
            Button("이름 바꾸기") { startEditingName() }
            Button("Finder에서 보기") { library.reveal(url) }
            Divider()
            Button("휴지통으로 이동", role: .destructive) { library.moveToTrash(url) }
        }
        .task(id: url) {
            thumbnail = await Thumbnails.load(url)
        }
    }

    private var preview: some View {
        // 미리보기도 실제 바탕화면과 같은 방식으로 보여 준다.
        (library.fitMode == .fit ? Color(nsColor: library.barColor.nsColor) : Color.secondary.opacity(0.12))
            .aspectRatio(Self.screenRatio, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    let image = Image(decorative: thumbnail, scale: 1).resizable()
                    if library.fitMode == .fill {
                        image.scaledToFill()
                    } else {
                        image.scaledToFit()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .contentShape(Rectangle())
    }

    private var nameRow: some View {
        HStack(spacing: 6) {
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("적용됨")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            if isEditingName {
                // Return: 저장, Esc: 취소, 다른 곳을 누르면 저장
                TextField(text: $draftName, prompt: Text("")) { Text("이름") }
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onSubmit(commitName)
                    .onExitCommand(perform: cancelEditingName)
                    .onChange(of: isNameFieldFocused) { _, focused in
                        if !focused { commitName() }
                    }
                    .onAppear {
                        DispatchQueue.main.async { isNameFieldFocused = true }
                    }
            } else {
                Text(name)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                // 화면에는 아이콘만 보이고, 이름은 음성 읽기용으로만 붙인다.
                Button("이름 바꾸기", systemImage: "pencil", action: startEditingName)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func startEditingName() {
        draftName = name
        isEditingName = true
    }

    private func commitName() {
        guard isEditingName else { return }
        isEditingName = false
        library.rename(url, to: draftName)
    }

    private func cancelEditingName() {
        isEditingName = false
    }

    // 흰색 여백이 창 배경에 묻히지 않도록 평소에도 옅은 테두리를 둔다.
    private var borderColor: Color {
        if isCurrent { return .accentColor }
        return isHovering ? Color.secondary.opacity(0.6) : Color.primary.opacity(0.12)
    }

    private var borderWidth: CGFloat {
        if isCurrent { return 4 }
        return isHovering ? 2 : 1
    }
}

/// 큰 원본 대신 작은 미리보기를 만들어 쓴다.
private enum Thumbnails {
    private static let cache = NSCache<NSURL, CGImage>()

    static func load(_ url: URL) async -> CGImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 720,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}
