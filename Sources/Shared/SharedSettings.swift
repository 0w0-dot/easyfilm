import Foundation

/// 본 앱과 도우미가 함께 쓰는 값. 공용 설정은 본 앱의 설정 영역에 저장한다.
enum SharedSettings {
    static let appID = "io.github.0w0-dot.easyfilm"
    static let helperID = "io.github.0w0-dot.easyfilm.helper"

    /// 도우미에서 배경화면 폴더를 바꾸면 본 앱에 알린다. object에 새 폴더 경로를 담는다.
    static let libraryFolderChanged = Notification.Name("io.github.0w0-dot.easyfilm.libraryFolderChanged")

    /// 초콜릿 하나 사주기 창에 띄우는 Ko-fi 후원 패널. 비워 두면 메뉴에 나오지 않는다.
    /// 뒤의 값은 다른 사이트에 끼워 넣는 용도의 작은 패널 모양으로 보여 달라는 뜻이다.
    static let chocolateURL = URL(string: "https://ko-fi.com/iwanthappyworld/?hidefeed=true&widget=true&embed=true")

    private static let libraryFolderKey = "libraryFolder"

    private static var appDefaults: UserDefaults {
        Bundle.main.bundleIdentifier == appID ? .standard : UserDefaults(suiteName: appID) ?? .standard
    }

    static var libraryFolder: URL {
        get {
            if let path = appDefaults.string(forKey: libraryFolderKey) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            // 처음 정한 폴더를 기억해 둔다. 기본 폴더 이름은 언어를 따르므로,
            // 기억하지 않으면 맥 언어를 바꿨을 때 다른 폴더를 보게 된다.
            let folder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Pictures", isDirectory: true)
                .appendingPathComponent(L("배경화면"), isDirectory: true)
            appDefaults.set(folder.path, forKey: libraryFolderKey)
            return folder
        }
        set { appDefaults.set(newValue.path, forKey: libraryFolderKey) }
    }
}
