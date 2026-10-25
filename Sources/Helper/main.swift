import AppKit

// Dock 아이콘 없이 뒤에서 돌며 메뉴 막대 아이콘과 Dock 클릭 기능을 맡는 도우미.
MainActor.assumeIsolated {
    // 본 앱이 새 버전을 깔았는지 알 수 있도록 지금 도는 실행 파일의 시각을 남긴다.
    if let path = Bundle.main.executablePath,
       let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date {
        UserDefaults.standard.set(modified.timeIntervalSince1970, forKey: "runningExecutableDate")
    }

    let minimizer = DockClickMinimizer()
    minimizer.start()
    let statusMenu = StatusMenu(minimizer: minimizer)
    withExtendedLifetime((minimizer, statusMenu)) {
        NSApplication.shared.setActivationPolicy(.accessory)
        HelperMainMenu.install()
        NSApplication.shared.run()
    }
}
