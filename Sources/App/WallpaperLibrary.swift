import AppKit
import UniformTypeIdentifiers

/// 이미지를 화면에 맞추는 방식.
enum FitMode: String, CaseIterable, Identifiable {
    case fill, fit
    var id: Self { self }
    var title: String { self == .fill ? L("꽉 채우기") : L("원본 비율 유지") }
}

/// 원본 비율 유지일 때 이미지 바깥의 남는 부분을 칠하는 색.
enum BarColor: String, CaseIterable, Identifiable {
    case black, white
    var id: Self { self }
    var title: String { self == .black ? L("검정") : L("흰색") }
    var nsColor: NSColor {
        self == .black ? NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1) : NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    }
}

/// 배경화면 폴더(기본: ~/Pictures/배경화면)에 모아 둔 이미지를 관리하고 바탕화면에 적용한다.
@MainActor
final class WallpaperLibrary: ObservableObject {
    @Published private(set) var images: [URL] = []
    @Published private(set) var current: URL?
    @Published var errorMessage: String?

    // 설정을 바꾸면 지금 바탕화면에 바로 다시 적용한다.
    @Published var fitMode: FitMode { didSet { settingsChanged() } }
    @Published var barColor: BarColor { didSet { settingsChanged() } }

    private(set) var folder: URL
    private var watcher: DispatchSourceFileSystemObject?

    init() {
        let defaults = UserDefaults.standard
        fitMode = defaults.string(forKey: Self.fitModeKey).flatMap(FitMode.init) ?? .fill
        barColor = defaults.string(forKey: Self.barColorKey).flatMap(BarColor.init) ?? .black

        folder = SharedSettings.libraryFolder
        useFolder(folder)

        // 시스템 설정에서 바탕화면을 바꾸고 돌아와도 표시가 맞도록 한다.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }

        // 메뉴 막대에서 폴더를 바꾸면 열려 있는 창도 바로 따라간다.
        DistributedNotificationCenter.default().addObserver(
            forName: SharedSettings.libraryFolderChanged, object: nil, queue: .main
        ) { [weak self] note in
            guard let path = note.object as? String else { return }
            MainActor.assumeIsolated { self?.useFolder(URL(fileURLWithPath: path, isDirectory: true)) }
        }
    }

    private func useFolder(_ url: URL) {
        watcher?.cancel()
        folder = url
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
        watchFolder()
    }

    func reload() {
        let keys: [URLResourceKey] = [.contentTypeKey, .addedToDirectoryDateKey, .creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        images = files.filter(Self.isImage).sorted { Self.addedDate($0) > Self.addedDate($1) }

        // TopNotch 같은 앱이 바탕화면을 가공본으로 바꿔 끼우면 시스템이 알려 주는 경로가 달라진다.
        // 그럴 때는 이 앱에서 마지막으로 적용한 이미지를 현재 것으로 본다.
        let desktop = NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        let lastApplied = UserDefaults.standard.string(forKey: Self.lastAppliedKey).map(URL.init(fileURLWithPath:))
        current = [desktop, lastApplied].compactMap { $0 }.first { candidate in
            images.contains { Self.samePath($0, candidate) }
        }
    }

    func isCurrent(_ url: URL) -> Bool {
        current.map { Self.samePath($0, url) } ?? false
    }

    /// 연결된 모든 화면의 바탕화면을 현재 맞춤 설정으로 바꾼다.
    func apply(_ url: URL) {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: fitMode == .fill,
            .fillColor: barColor.nsColor,
        ]
        do {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
            }
            current = url
            UserDefaults.standard.set(url.path, forKey: Self.lastAppliedKey)
        } catch {
            errorMessage = String(format: L("바탕화면을 바꾸지 못했어요.\n%@"), error.localizedDescription)
        }
    }

    /// 이미지 파일이나 폴더를 받아 보관 폴더로 복사한다.
    func add(_ urls: [URL]) {
        var failed: [String] = []
        for source in urls.flatMap(Self.expand) {
            guard source.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL,
                  let destination = destination(for: source) else { continue }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                failed.append(source.lastPathComponent)
            }
        }
        if !failed.isEmpty {
            errorMessage = L("다음 파일을 넣지 못했어요.") + "\n" + failed.joined(separator: "\n")
        }
        reload()
    }

    func addWithPanel() {
        let panel = NSOpenPanel()
        panel.prompt = L("추가")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            add(panel.urls)
        }
    }

    /// 확장자는 그대로 두고 이름만 바꾼다.
    func rename(_ url: URL, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != url.deletingPathExtension().lastPathComponent else { return }
        guard !name.contains("/"), !name.contains(":"), !name.hasPrefix(".") else {
            errorMessage = L("이름에 / 와 : 는 쓸 수 없고, 점(.)으로 시작할 수 없어요.")
            return
        }

        let ext = url.pathExtension
        let destination = ext.isEmpty
            ? folder.appendingPathComponent(name)
            : folder.appendingPathComponent(name).appendingPathExtension(ext)
        // 대소문자만 바꾸는 경우는 같은 파일로 잡히므로 막지 않는다.
        let isCaseOnlyChange = destination.path.lowercased() == url.path.lowercased()
        guard isCaseOnlyChange || !FileManager.default.fileExists(atPath: destination.path) else {
            errorMessage = String(format: L("‘%@’ 이름의 이미지가 이미 있어요."), name)
            return
        }

        let wasCurrent = isCurrent(url)
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            errorMessage = String(format: L("이름을 바꾸지 못했어요.\n%@"), error.localizedDescription)
            return
        }
        // 바탕화면은 파일 경로를 기억하므로, 지금 쓰는 이미지면 새 경로로 다시 적용한다.
        if wasCurrent { apply(destination) }
        reload()
    }

    func moveToTrash(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        reload()
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFolder() {
        NSWorkspace.shared.open(folder)
    }

    // MARK: - 내부

    private static let lastAppliedKey = "lastAppliedPath"
    private static let fitModeKey = "fitMode"
    private static let barColorKey = "barColor"

    private func settingsChanged() {
        UserDefaults.standard.set(fitMode.rawValue, forKey: Self.fitModeKey)
        UserDefaults.standard.set(barColor.rawValue, forKey: Self.barColorKey)
        if let current { apply(current) }
    }

    private static func samePath(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path == b.standardizedFileURL.path
    }

    /// 같은 이름에 같은 크기면 이미 넣은 파일로 보고 건너뛴다(nil). 이름만 같으면 번호를 붙인다.
    private func destination(for source: URL) -> URL? {
        let fm = FileManager.default
        let name = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = folder.appendingPathComponent(source.lastPathComponent)
        var number = 2
        while fm.fileExists(atPath: candidate.path) {
            if Self.fileSize(candidate) == Self.fileSize(source) { return nil }
            candidate = folder.appendingPathComponent("\(name) \(number)").appendingPathExtension(ext)
            number += 1
        }
        return candidate
    }

    /// 폴더가 바뀌면(Finder에서 넣거나 지우면) 목록을 새로 읽는다.
    private func watchFolder() {
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: .write, queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    private static func expand(_ url: URL) -> [URL] {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        guard isDirectory else { return isImage(url) ? [url] : [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter(isImage)
    }

    private static func isImage(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        return type?.conforms(to: .image) == true && type?.conforms(to: .svg) == false
    }

    private static func addedDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        return values?.addedToDirectoryDate ?? values?.creationDate ?? .distantPast
    }

    private static func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
