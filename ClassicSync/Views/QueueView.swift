import SwiftUI

struct QueueView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPlaylistPicker = false
    @State private var playlists: [Playlist] = []
    @State private var isLoadingPlaylists = false

    private let bridge = AppleScriptBridge()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Queue")
                    .font(.headline)
                Spacer()
                Button {
                    loadPlaylists()
                    showPlaylistPicker = true
                } label: {
                    Label("Add Playlist", systemImage: "plus")
                        .font(.callout)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if appState.queue.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(appState.queue.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(track: track, index: index + 1)
                    }
                    .onDelete { offsets in
                        appState.removeFromQueue(at: offsets)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showPlaylistPicker) {
            PlaylistPickerView(playlists: playlists, isLoading: isLoadingPlaylists) { playlist in
                loadTracks(from: playlist)
                showPlaylistPicker = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No tracks queued")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add a playlist from your Music library to get started.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Playlist") {
                loadPlaylists()
                showPlaylistPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadPlaylists() {
        isLoadingPlaylists = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = bridge.getLibraryPlaylists()
            DispatchQueue.main.async {
                playlists = result
                isLoadingPlaylists = false
            }
        }
    }

    private func loadTracks(from playlist: Playlist) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tracks = bridge.getTracksInPlaylist(id: playlist.id)
            DispatchQueue.main.async {
                appState.addToQueue(tracks)
            }
        }
    }
}

struct TrackRowView: View {
    let track: TrackInfo
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.callout.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .lineLimit(1)
                    .fontWeight(.medium)
                Text("\(track.artist) — \(track.album)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct PlaylistPickerView: View {
    let playlists: [Playlist]
    let isLoading: Bool
    let onSelect: (Playlist) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Playlist")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(.regularMaterial)
            Divider()

            if isLoading {
                ProgressView("Loading playlists…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No playlists found")
                        .foregroundColor(.secondary)
                    Text("Make sure Music.app is open and has playlists.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(playlists) { playlist in
                    Button {
                        onSelect(playlist)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(playlist.name).foregroundColor(.primary)
                                Text("\(playlist.trackCount) tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 380, height: 480)
    }
}
