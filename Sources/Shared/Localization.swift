import Foundation

/// 화면 글을 사용 언어(한국어, 영어, 일본어)로 바꾼다.
/// 키는 한국어 문장이고, 번역은 Resources/<언어>.lproj/Localizable.strings에 있다.
/// SwiftUI의 Text("…")처럼 글자를 그대로 쓰는 곳은 이 함수 없이도 바뀐다.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
