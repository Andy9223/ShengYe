import SwiftUI

@main
struct VoicePageApp: App {
    @StateObject private var model = ReaderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开书籍…") {
                    NotificationCenter.default.post(name: .openBook, object: nil)
                }
                .keyboardShortcut("o")
            }

            CommandMenu("朗读") {
                Button(model.isSpeaking ? "暂停" : "开始或继续") {
                    NotificationCenter.default.post(name: .toggleSpeech, object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}

extension Notification.Name {
    static let openBook = Notification.Name("VoicePage.openBook")
    static let toggleSpeech = Notification.Name("VoicePage.toggleSpeech")
}
