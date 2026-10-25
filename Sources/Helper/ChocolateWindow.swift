import AppKit
import WebKit

/// Ko-fi 후원 패널을 브라우저로 넘기지 않고 작은 창에 띄운다.
/// 결제 중에 PayPal 등이 새 창을 열면 그것도 앱 안의 창으로 띄운다.
@MainActor
final class ChocolateWindow: NSObject, WKUIDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var popups: [NSWindow] = []

    func show() {
        guard let url = SharedSettings.chocolateURL else { return }
        if window == nil { makeWindow() }
        // 닫았다가 다시 열면 처음 화면부터 보여 준다.
        if window?.isVisible == false { webView?.load(URLRequest(url: url)) }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// 결제 도중 다른 앱이나 시스템 설정이 앞으로 와도 가려지지 않게 늘 위에 띄운다.
    private func keepOnTop(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    private func makeWindow() {
        let webView = makeWebView(configuration: WKWebViewConfiguration())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = L("초콜릿 하나 사주기")
        window.contentView = webView
        window.isReleasedWhenClosed = false
        keepOnTop(window)
        window.center()
        self.window = window
        self.webView = webView
    }

    private func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        // Safari로 보이게 해서 결제 페이지가 막지 않게 한다.
        configuration.applicationNameForUserAgent = "Version/26.0 Safari/605.1.15"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        return webView
    }

    // MARK: - 결제 창 같은 새 창

    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let popupView = makeWebView(configuration: configuration)
        let popup = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: windowFeatures.width?.doubleValue ?? 480,
                height: windowFeatures.height?.doubleValue ?? 640
            ),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        // 어느 사이트에 결제 정보를 넣는지 보이도록 주소를 제목에 둔다.
        popup.title = navigationAction.request.url?.host ?? ""
        popup.contentView = popupView
        popup.isReleasedWhenClosed = false
        popup.delegate = self
        keepOnTop(popup)
        popup.center()
        popup.makeKeyAndOrderFront(nil)
        popups.append(popup)
        return popupView
    }

    // 결제 창이 스스로 닫히면 창도 닫는다.
    func webViewDidClose(_ webView: WKWebView) {
        popups.first { $0.contentView === webView }?.close()
    }

    func windowWillClose(_ notification: Notification) {
        popups.removeAll { $0 === notification.object as? NSWindow }
    }
}

/// 도우미는 메뉴 막대가 보이지 않지만, 입력칸에서 복사/붙여넣기와 ⌘W가 되도록 메뉴를 둔다.
enum HelperMainMenu {
    @MainActor
    static func install() {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let menu = NSMenu(title: L(title))
            items.forEach(menu.addItem)
            let holder = NSMenuItem()
            holder.submenu = menu
            main.addItem(holder)
        }
        func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let item = NSMenuItem(title: L(title), action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            return item
        }
        submenu("Easyfilm", [item("닫기", #selector(NSWindow.performClose(_:)), "w")])
        submenu("편집", [
            item("실행 취소", Selector(("undo:")), "z"),
            item("실행 복귀", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("오려두기", #selector(NSText.cut(_:)), "x"),
            item("복사하기", #selector(NSText.copy(_:)), "c"),
            item("붙여넣기", #selector(NSText.paste(_:)), "v"),
            item("전체 선택", #selector(NSText.selectAll(_:)), "a"),
        ])
        NSApp.mainMenu = main
    }
}
