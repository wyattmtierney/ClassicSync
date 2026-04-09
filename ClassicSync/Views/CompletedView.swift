import SwiftUI

struct CompletedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Completed")
                    .font(.headline)
                Spacer()
                if !appState.completedTracks.isEmpty {
                    Text("\(appState.completedTracks.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if appState.completedTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No completed tracks")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.completedTracks) { completed in
                    CompletedTrackRow(completed: completed)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(
                                    completed.fileURL.path,
                                    inFileViewerRootedAtPath: completed.fileURL.deletingLastPathComponent().path
                                )
                            }
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(completed.fileURL.path, forType: .string)
                            }
                        }
                }
                .listStyle(.inset)

                Divider()

                // Output folder info
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text(appState.outputFolder.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Open") {
                        NSWorkspace.shared.open(appState.outputFolder)
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
    }
}

struct CompletedTrackRow: View {
    let completed: CompletedTrack

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.callout)

            VStack(alignment: .leading, spacing: 2) {
                Text(completed.track.name)
                    .lineLimit(1)
                    .fontWeight(.medium)
                Text("\(completed.track.artist) — \(completed.track.album)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(completed.fileSizeString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Text(formatTime(completed.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
