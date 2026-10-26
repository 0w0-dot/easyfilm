import AppKit
import CryptoKit
import UniformTypeIdentifiers

extension NSScreen {
    /// 메뉴 막대 높이(포인트). 노치가 있는 화면은 노치 높이와 같다. 메뉴 막대가 없는 화면은 0.
    var menuBarHeight: CGFloat {
        max(safeAreaInsets.top, frame.maxY - visibleFrame.maxY)
    }
}

/// "메뉴 막대 검게"를 켰을 때 쓰는 바탕화면을 화면마다 그린다.
/// 메뉴 막대 자리를 검게 칠하고 그 아래에 이미지를 맞춰 넣어, 노치가 검은 띠 안으로 숨게 한다.
/// 바탕화면은 그린 파일을 계속 가리키므로, 원본이 남아 있는 동안은 지우지 않는다.
/// 쓰고 있는 파일을 지우면 macOS가 기본 배경화면으로 되돌아간다.
enum WallpaperRenderer {
    /// 그릴 화면의 크기. 모두 픽셀 단위다.
    struct Target: Sendable {
        let width: Int
        let height: Int
        let menuBar: Int
        let cornerRadius: CGFloat

        @MainActor init(_ screen: NSScreen) {
            let scale = screen.backingScaleFactor
            width = Int((screen.frame.width * scale).rounded())
            height = Int((screen.frame.height * scale).rounded())
            menuBar = Int((screen.menuBarHeight * scale).rounded())
            cornerRadius = 10 * scale
        }
    }

    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(SharedSettings.appID, isDirectory: true)

    /// 그리는 방식을 바꾸면 올린다. 예전 방식으로 그린 파일을 다시 쓰지 않게 된다.
    private static let version = "1"

    /// HEIC로 저장한다. HEIC를 쓸 수 없는 맥이면 JPEG로 저장한다.
    private static let format: UTType = {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains(UTType.heic.identifier) ? .heic : .jpeg
    }()

    /// 원본을 화면 크기로 그려 파일로 남기고 그 위치를 돌려준다. 같은 조건으로 그린 것이 있으면 그대로 쓴다.
    static func render(_ source: URL, for target: Target, fitMode: FitMode, barColor: BarColor) throws -> URL {
        let values = try source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let key = [
            version, source.path,
            "\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)", "\(values.fileSize ?? 0)",
            "\(target.width)x\(target.height)", "\(target.menuBar)", fitMode.rawValue, barColor.rawValue,
        ].joined(separator: "\n")
        let name = SHA256.hash(data: Data(key.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
        let output = folder.appendingPathComponent(name).appendingPathExtension(format.preferredFilenameExtension ?? "heic")
        if FileManager.default.fileExists(atPath: output.path) { return output }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary),
              let context = CGContext(
                  data: nil, width: target.width, height: target.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.displayP3)!,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: source])
        }

        let width = CGFloat(target.width), height = CGFloat(target.height)
        let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        context.setFillColor(barColor.nsColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // 이미지는 메뉴 막대 아래 영역에 맞춘다. 그래야 원본 비율 유지일 때 가려지는 곳이 없다.
        let area = CGRect(x: 0, y: 0, width: width, height: height - CGFloat(target.menuBar))
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let scale = fitMode == .fill
            ? max(area.width / imageWidth, area.height / imageHeight)
            : min(area.width / imageWidth, area.height / imageHeight)
        let drawn = CGSize(width: imageWidth * scale, height: imageHeight * scale)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(
            x: area.midX - drawn.width / 2, y: area.midY - drawn.height / 2,
            width: drawn.width, height: drawn.height
        ))

        // 메뉴 막대 자리를 검게 칠하고, 바로 아래 양쪽 모서리를 화면 모서리처럼 둥글게 깎는다.
        // 아래 모서리는 화면 밖으로 내보내서 둥글지 않게 한다.
        let radius = target.cornerRadius
        let band = CGMutablePath()
        band.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        band.addRoundedRect(
            in: CGRect(x: 0, y: -radius, width: width, height: area.height + radius),
            cornerWidth: radius, cornerHeight: radius
        )
        context.addPath(band)
        context.setFillColor(black)
        context.fillPath(using: .evenOdd)

        guard let rendered = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // 다 쓴 뒤에 이름을 바꿔, 쓰다 만 파일을 바탕화면으로 쓰는 일이 없게 한다.
        let partial = folder.appendingPathComponent(".\(UUID().uuidString)")
        guard let destination = CGImageDestinationCreateWithURL(
            partial as CFURL, format.identifier as CFString, 1, nil
        ) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(
            destination, rendered, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: partial)
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            try FileManager.default.moveItem(at: partial, to: output)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            // 같은 그림을 동시에 그렸다면 먼저 끝난 쪽을 쓴다.
            guard FileManager.default.fileExists(atPath: output.path) else { throw error }
        }
        return output
    }

    // MARK: - 그린 파일과 원본의 짝

    private static let sourcesKey = "renderedSources"

    /// 그린 파일 이름 → 원본 경로.
    private static var sources: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: sourcesKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: sourcesKey) }
    }

    @MainActor static func record(_ rendered: URL, from source: URL) {
        sources[rendered.lastPathComponent] = source.path
    }

    /// 이 앱이 그린 파일이면 원본 위치를 돌려준다.
    @MainActor static func source(of url: URL) -> URL? {
        guard url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL,
              let path = sources[url.lastPathComponent] else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 원본이 사라진 그림을 지운다. 지금 바탕화면에 떠 있는 것은 남긴다.
    @MainActor static func prune(keeping inUse: [URL]) {
        let keep = Set(inUse.map(\.standardizedFileURL.path))
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let known = sources
        var remaining: [String: String] = [:]
        for file in files {
            let name = file.lastPathComponent
            let source = known[name]
            if keep.contains(file.standardizedFileURL.path)
                || source.map({ FileManager.default.fileExists(atPath: $0) }) == true {
                remaining[name] = source
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
        sources = remaining
    }
}
