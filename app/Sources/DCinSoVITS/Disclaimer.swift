import Foundation

enum AppInfo {
    static let name = "DCinSoVITS"
    static let creator = "HolicJin"
    static let version = "1.0.0"
}

/// 이용 고지 문구 (현재 UI 언어로 표시)
enum Disclaimer {
    static var title: String { tr(.disclaimerTitle) }
    static var body: String { tr(.disclaimerBody) }
    static var footer: String { tr(.footer) }
}
