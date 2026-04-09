import SwiftUI

@main
struct ClassicSyncApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}   // hide File > New
            CommandMenu("Recording") {
                Button("Start Queue") {}
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Stop") {}
                    .keyboardShortcut(".", modifiers: [.command])
            }
        }

        // Menu bar extra
        MenuBarExtra("ClassicSync", systemImage: menuBarIcon) {
            menuBarContent
        }
    }

    private var menuBarIcon: String {
        switch appState.recordingStatus {
        case .recording: return "record.circle.fill"
        case .encoding:  return "gearshape.fill"
        case .paused:    return "pause.circle.fill"
        default:         return "hifi.speaker.2"
        }
    }

    @ViewBuilder
    private var menuBarContent: some View {
        switch appState.recordingStatus {
        case .recording(let track):
            Text("Recording: \(track.name)")
            Text(track.artist).foregroundColor(.secondary)
        case .encoding(let track, let p):
            Text("Encoding: \(track.name)")
            Text("\(Int(p * 100))% complete").foregroundColor(.secondary)
        case .idle:
            Text("ClassicSync — Idle")
        default:
            Text("ClassicSync")
        }
        Divider()
        Button("Open ClassicSync") {
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}
