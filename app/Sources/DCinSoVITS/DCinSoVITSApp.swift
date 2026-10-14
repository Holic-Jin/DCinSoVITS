import AppKit
import SwiftUI

@main
struct DCinSoVITSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    // App 구조체는 실행 시 한 번만 생성되므로 모델을 그대로 보관한다
    private let model = AppModel()
    @AppStorage("acceptedDisclaimer.v1") private var accepted = false

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            Group {
                if accepted {
                    ContentView(model: model)
                } else {
                    DisclaimerView { accepted = true }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                model.cancel()
                model.resetJob()  // 추출 오디오 등 작업 데이터는 종료 시 삭제
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(tr(.aboutApp, AppInfo.name)) {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: AppInfo.name,
                        .applicationVersion: AppInfo.version,
                        .credits: NSAttributedString(string: tr(.madeBy, AppInfo.creator) + "\n\n" + Disclaimer.body),
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // swift run 으로 실행해도 일반 앱처럼 Dock/메뉴가 보이도록
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
