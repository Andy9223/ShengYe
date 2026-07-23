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
                Button(model.localized(.openBookCommand)) {
                    NotificationCenter.default.post(name: .openBook, object: nil)
                }
                .keyboardShortcut("o")
            }

            CommandMenu(model.localized(.readingMenu)) {
                Button(
                    model.isSpeaking
                        ? model.localized(.pause)
                        : model.localized(.startOrContinue)
                ) {
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
