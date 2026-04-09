import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var coordinator: RecordingCoordinator

    init(appState: AppState) {
        _coordinator = StateObject(wrappedValue: RecordingCoordinator(appState: appState))
    }

    var body: some View {
        if !appState.isSetupComplete {
            SetupView()
                .frame(minWidth: 660, minHeight: 520)
        } else {
            mainView
                .frame(minWidth: 900, minHeight: 600)
                .alert("ClassicSync", isPresented: $appState.showAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(appState.alertMessage ?? "")
                }
        }
    }

    // MARK: - Main layout

    private var mainView: some View {
        HStack(spacing: 0) {
            // Left: Queue (230pt)
            QueueView()
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Center: Now Recording
            VStack(spacing: 0) {
                NowRecordingView()

                Divider()

                controlBar
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Right: Completed (230pt)
            CompletedView()
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                outputFolderPicker
            }
            ToolbarItem(placement: .status) {
                statusLabel
            }
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 16) {
            // Start / Resume
            if case .idle = appState.recordingStatus {
                Button {
                    coordinator.startQueue()
                } label: {
                    Label("Start Queue", systemImage: "play.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.queue.isEmpty)
            } else if case .paused = appState.recordingStatus {
                Button {
                    coordinator.resumeQueue()
                } label: {
                    Label("Resume", systemImage: "play.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
            }

            // Pause
            if case .recording = appState.recordingStatus {
                Button {
                    coordinator.pauseQueue()
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            // Skip
            if case .recording = appState.recordingStatus {
                Button {
                    coordinator.skipCurrentTrack()
                } label: {
                    Label("Skip", systemImage: "forward.end")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            // Stop
            if appState.recordingStatus != .idle {
                Button {
                    coordinator.stopQueue()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Spacer()

            // Disk space
            if let info = diskInfo {
                Text(info)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var diskInfo: String? {
        guard FileManager.default.fileExists(atPath: appState.outputFolder.path) ||
              (try? FileManager.default.createDirectory(at: appState.outputFolder, withIntermediateDirectories: true)) != nil
        else { return nil }
        return DiskSpaceChecker.formattedAvailable(at: appState.outputFolder)
    }

    // MARK: - Toolbar items

    private var outputFolderPicker: some View {
        Button {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose Output Folder"
            if panel.runModal() == .OK, let url = panel.url {
                appState.outputFolder = url
            }
        } label: {
            Label("Output: \(appState.outputFolder.lastPathComponent)", systemImage: "folder")
                .font(.callout)
        }
    }

    private var statusLabel: some View {
        Group {
            switch appState.recordingStatus {
            case .idle:
                Label("Idle", systemImage: "circle").foregroundColor(.secondary)
            case .recording:
                Label("Recording", systemImage: "record.circle").foregroundColor(.red)
            case .encoding:
                Label("Encoding", systemImage: "gearshape").foregroundColor(.orange)
            case .paused:
                Label("Paused", systemImage: "pause.circle").foregroundColor(.orange)
            case .finished:
                Label("Done", systemImage: "checkmark.circle").foregroundColor(.green)
            case .failed:
                Label("Error", systemImage: "exclamationmark.triangle").foregroundColor(.red)
            }
        }
        .font(.caption)
    }
}
