import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let library = WallpaperLibrary()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        DockHelper.start()
        showWindow()
    }

    // 이미 켜져 있을 때 앱을 다시 열면 창을 보여 준다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    // 창을 닫으면 앱도 끝낸다. Dock 기능은 도우미가 따로 맡는다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func showWindow() {
        let window = self.window ?? makeWindow()
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: ContentView().environmentObject(library))
        hosting.sizingOptions = [.minSize]
        hosting.sceneBridgingOptions = [.toolbars]

        let window = NSWindow(contentViewController: hosting)
        window.title = "Easyfilm"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 920, height: 640))
        if !window.setFrameUsingName("main") { window.center() }
        window.setFrameAutosaveName("main")
        return window
    }

    @objc private func addImages() {
        library.addWithPanel()
    }

    // MARK: - 메뉴 막대

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: L(title))
            items.forEach(menu.addItem)
            let holder = NSMenuItem()
            holder.submenu = menu
            mainMenu.addItem(holder)
            return menu
        }

        func item(
            _ title: String, _ action: Selector, _ key: String = "",
            _ modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil
        ) -> NSMenuItem {
            let item = NSMenuItem(title: L(title), action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            return item
        }

        _ = submenu("Easyfilm", [
            item("Easyfilm에 관하여", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Easyfilm 가리기", #selector(NSApplication.hide(_:)), "h"),
            item("기타 가리기", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("모두 보기", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Easyfilm 종료", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("파일", [
            item("이미지 추가…", #selector(addImages), "o", target: self),
            .separator(),
            item("닫기", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = submenu("편집", [
            item("실행 취소", Selector(("undo:")), "z"),
            item("실행 복귀", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("오려두기", #selector(NSText.cut(_:)), "x"),
            item("복사하기", #selector(NSText.copy(_:)), "c"),
            item("붙여넣기", #selector(NSText.paste(_:)), "v"),
            item("전체 선택", #selector(NSText.selectAll(_:)), "a"),
        ])
        NSApp.windowsMenu = submenu("윈도우", [
            item("최소화", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("확대/축소", #selector(NSWindow.performZoom(_:))),
        ])
        return mainMenu
    }
}

/// 메뉴 막대 아이콘과 Dock 기능을 맡는 도우미(Easyfilm Helper)를 뒤에서 늘 돌게 해 둔다.
/// 사용자 LaunchAgent로 등록해서 맥을 켤 때마다 시작되고, 비정상으로 꺼지면 launchd가 다시 켠다.
/// 메뉴에서 "종료"로 끄면 다시 켜지지 않고, 다음에 Easyfilm을 열거나 맥을 켜면 돌아온다.
enum DockHelper {
    private static let label = SharedSettings.helperID

    static func start() {
        let executable = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/Easyfilm Helper.app/Contents/MacOS/EasyfilmHelper")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { return }

        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
        let plist: NSDictionary = [
            "Label": label,
            "ProgramArguments": [executable.path],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        let domain = "gui/\(getuid())"

        // 앱 위치가 바뀌었으면 등록을 새로 고친다.
        if NSDictionary(contentsOf: plistURL) != plist {
            launchctl("bootout", "\(domain)/\(label)")
            try? FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? plist.write(to: plistURL)
        }
        // 처음 등록하면 바로 켜진다. 이미 등록돼 있었다면 꺼져 있을 때만 켜고,
        // 새 버전이 깔렸을 때만 다시 띄운다. 괜히 다시 띄우면 메뉴 막대 아이콘이 깜빡인다.
        if !launchctl("bootstrap", domain, plistURL.path) {
            let isNewVersion = modificationDate(of: executable) != runningHelperDate()
            if isNewVersion {
                launchctl("kickstart", "-k", "\(domain)/\(label)")
            } else {
                launchctl("kickstart", "\(domain)/\(label)")
            }
        }
    }

    private static func modificationDate(of url: URL) -> Double {
        let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        return date?.timeIntervalSince1970 ?? 0
    }

    /// 도우미가 켜질 때 자기 실행 파일 시각을 남겨 둔다.
    private static func runningHelperDate() -> Double {
        UserDefaults(suiteName: SharedSettings.helperID)?.double(forKey: "runningExecutableDate") ?? -1
    }

    @discardableResult
    private static func launchctl(_ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
