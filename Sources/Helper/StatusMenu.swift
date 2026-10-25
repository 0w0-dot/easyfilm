import AppKit
import ApplicationServices

/// 메뉴 막대의 필름 아이콘과 그 메뉴.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let minimizer: DockClickMinimizer
    private let chocolateWindow = ChocolateWindow()

    init(minimizer: DockClickMinimizer) {
        self.minimizer = minimizer
        super.init()
        statusItem.button?.image = FilmIcon.make()
        statusItem.button?.setAccessibilityLabel("Easyfilm")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // 열 때마다 지금 상태로 다시 채운다.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("Easyfilm 열기", #selector(openApp)))
        menu.addItem(.separator())

        // 권한이 없으면 실제로 동작하지 않으니 꺼진 것으로 보여 준다.
        let dock = item("Dock 클릭으로 최소화", #selector(toggleDock))
        dock.state = minimizer.isEnabled && AXIsProcessTrusted() ? .on : .off
        menu.addItem(dock)

        let folderMenu = NSMenu()
        // 지금 폴더 위치는 누를 수 없는 상태 표시로 보여 준다.
        folderMenu.addItem(NSMenuItem(
            title: (SharedSettings.libraryFolder.path as NSString).abbreviatingWithTildeInPath,
            action: nil, keyEquivalent: ""
        ))
        folderMenu.addItem(.separator())
        folderMenu.addItem(item("Finder에서 열기", #selector(openFolder)))
        folderMenu.addItem(item("다른 폴더 선택…", #selector(chooseFolder)))
        let folder = NSMenuItem(title: L("배경화면 폴더"), action: nil, keyEquivalent: "")
        folder.submenu = folderMenu
        menu.addItem(folder)

        if SharedSettings.chocolateURL != nil {
            menu.addItem(.separator())
            menu.addItem(item("초콜릿 하나 사주기", #selector(openChocolate)))
        }

        menu.addItem(.separator())
        menu.addItem(item("종료", #selector(quit)))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: L(title), action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - 동작

    @objc private func openApp() {
        // 도우미는 Easyfilm.app/Contents/Helpers 안에 있다.
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    // 권한이 없을 때 누르면 켜 두고 권한 설정 화면을 연다. 권한을 켜면 바로 동작한다.
    @objc private func toggleDock() {
        guard AXIsProcessTrusted() else {
            minimizer.isEnabled = true
            minimizer.requestPermission()
            return
        }
        minimizer.isEnabled.toggle()
    }

    @objc private func openFolder() {
        let folder = SharedSettings.libraryFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("선택")
        panel.directoryURL = SharedSettings.libraryFolder
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SharedSettings.libraryFolder = url
        DistributedNotificationCenter.default().postNotificationName(
            SharedSettings.libraryFolderChanged, object: url.path, userInfo: nil, deliverImmediately: true
        )
    }

    @objc private func openChocolate() {
        chocolateWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
