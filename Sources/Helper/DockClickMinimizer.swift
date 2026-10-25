import AppKit
import ApplicationServices

/// 이미 맨 앞에 있는 앱의 Dock 아이콘을 다시 누르면 그 앱의 창을 모두 Dock으로 내린다.
/// 다른 앱의 창을 다루므로 손쉬운 사용 권한이 필요하다.
@MainActor
final class DockClickMinimizer {
    private var tap: CFMachPort?
    private var trustTimer: Timer?
    private var swallowNextMouseUp = false
    private var pendingMinimize: (() -> Void)?
    private let systemWide = AXUIElementCreateSystemWide()
    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    private static let enabledKey = "dockMinimizeEnabled"

    init() {
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    /// 메뉴 막대에서 켜고 끈다. 끄면 클릭을 전혀 건드리지 않는다.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if newValue {
                start()
            } else if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
            }
        }
    }

    func start() {
        guard isEnabled else { return }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }
        if AXIsProcessTrusted() {
            installTap()
            return
        }
        // 시스템 권한 창은 처음 한 번만 띄운다.
        let askedKey = "askedAccessibility"
        if !UserDefaults.standard.bool(forKey: askedKey) {
            UserDefaults.standard.set(true, forKey: askedKey)
            promptForPermission()
        }
        waitForPermission()
    }

    /// 손쉬운 사용 설정 화면을 연다. 목록에 도우미가 올라가도록 권한 요청도 함께 보낸다.
    func requestPermission() {
        promptForPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        waitForPermission()
    }

    private func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// 허용될 때까지 조용히 기다렸다가 켠다.
    private func waitForPermission() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.trustTimer = nil
                if self?.tap == nil { self?.installTap() }
                if self?.isEnabled == false, let tap = self?.tap { CGEvent.tapEnable(tap: tap, enable: false) }
            }
        }
    }

    private func installTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: dockClickCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// false를 돌려주면 그 클릭을 Dock에 넘기지 않는다.
    fileprivate func shouldPass(_ type: CGEventType, at point: CGPoint) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap, isEnabled { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            if let minimize = minimizeActionForClick(at: point) {
                swallowNextMouseUp = true
                // 클릭 처리를 늦추지 않도록 창 내리기는 이벤트를 돌려준 뒤에 한다.
                pendingMinimize = minimize
                DispatchQueue.main.async { [weak self] in
                    self?.pendingMinimize?()
                    self?.pendingMinimize = nil
                }
                return false
            }
        case .leftMouseUp:
            if swallowNextMouseUp {
                swallowNextMouseUp = false
                return false
            }
        default:
            break
        }
        return true
    }

    /// 누른 곳이 맨 앞 앱의 Dock 아이콘이고 내릴 창이 있으면, 창을 내리는 동작을 돌려준다.
    private func minimizeActionForClick(at point: CGPoint) -> (() -> Void)? {
        guard isNearDock(point),
              let front = NSWorkspace.shared.frontmostApplication,
              let item = element(at: point),
              isDockItem(item, for: front) else { return nil }

        let windows = standardWindows(of: front)
        guard !windows.isEmpty else { return nil }
        return {
            for window in windows {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            }
        }
    }

    /// Dock이 있는 화면 가장자리 근처를 누를 때만 확인해서 다른 클릭은 늦추지 않는다.
    private func isNearDock(_ point: CGPoint) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let orientation = dockDefaults?.string(forKey: "orientation") ?? "bottom"
        let band: CGFloat = 160
        for screen in NSScreen.screens {
            // NSScreen은 왼쪽 아래가 원점이고 클릭 위치는 왼쪽 위가 원점이라 맞춰서 비교한다.
            let f = screen.frame
            let rect = CGRect(x: f.minX, y: primary.frame.maxY - f.maxY, width: f.width, height: f.height)
            guard rect.contains(point) else { continue }
            switch orientation {
            case "left": return point.x < rect.minX + band
            case "right": return point.x > rect.maxX - band
            default: return point.y > rect.maxY - band
            }
        }
        return false
    }

    private func element(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success else {
            return nil
        }
        return element
    }

    private func isDockItem(_ element: AXUIElement, for app: NSRunningApplication) -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              pid == NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier,
              attribute(element, kAXSubroleAttribute) as? String == "AXApplicationDockItem",
              let url = attribute(element, kAXURLAttribute) as? URL,
              let bundleURL = app.bundleURL else { return false }
        return url.resolvingSymlinksInPath().path == bundleURL.resolvingSymlinksInPath().path
    }

    /// 내릴 수 있는 일반 창만 고른다. 이미 내려간 창, 전체 화면 창, 작은 패널은 뺀다.
    private func standardWindows(of app: NSRunningApplication) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        let windows = attribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.filter {
            attribute($0, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
                && attribute($0, kAXMinimizedAttribute) as? Bool == false
                && attribute($0, "AXFullScreen") as? Bool != true
        }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}

private func dockClickCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let minimizer = Unmanaged<DockClickMinimizer>.fromOpaque(refcon).takeUnretainedValue()
    let location = event.location
    // 이벤트 탭은 메인 실행 루프에 붙어 있어 항상 메인 스레드에서 불린다.
    let pass = MainActor.assumeIsolated { minimizer.shouldPass(type, at: location) }
    return pass ? Unmanaged.passUnretained(event) : nil
}
