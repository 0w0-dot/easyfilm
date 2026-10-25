import AppKit

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    // delegate는 약하게 잡히므로 앱이 도는 동안 살려 둔다.
    withExtendedLifetime(delegate) {
        NSApplication.shared.run()
    }
}
