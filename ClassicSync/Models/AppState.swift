import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Setup
    @Published var isSetupComplete: Bool {
        didSet { UserDefaults.standard.set(isSetupComplete, forKey: "setupComplete") }
    }
    @Published var blackHoleFound: Bool = false
    @Published var ffmpegFound: Bool = false
    @Published var ffmpegPath: String = ""

    // MARK: - Output
    @Published var outputFolder: URL {
        didSet { UserDefaults.standard.set(outputFolder.path, forKey: "outputFolder") }
    }

    // MARK: - Queue
    @Published var queue: [TrackInfo] = []
    @Published var completedTracks: [CompletedTrack] = []

    // MARK: - Recording state
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var currentTrack: TrackInfo?
    @Published var elapsedTime: Double = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 40)

    // MARK: - Playlists
    @Published var playlists: [Playlist] = []

    // MARK: - Errors
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    init() {
        isSetupComplete = UserDefaults.standard.bool(forKey: "setupComplete")
        let savedPath = UserDefaults.standard.string(forKey: "outputFolder")
        if let saved = savedPath {
            outputFolder = URL(fileURLWithPath: saved)
        } else {
            outputFolder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Music/ClassicSync")
        }
    }

    func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    func addToQueue(_ tracks: [TrackInfo]) {
        for track in tracks {
            if !queue.contains(where: { $0.id == track.id }) {
                queue.append(track)
            }
        }
    }

    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }

    func markCompleted(_ track: TrackInfo, fileURL: URL, fileSize: Int64, duration: Double) {
        let completed = CompletedTrack(
            track: track,
            fileURL: fileURL,
            fileSize: fileSize,
            duration: duration,
            completedAt: Date()
        )
        completedTracks.append(completed)
        queue.removeAll { $0.id == track.id }
    }
}

struct CompletedTrack: Identifiable {
    let id = UUID()
    let track: TrackInfo
    let fileURL: URL
    let fileSize: Int64
    let duration: Double
    let completedAt: Date

    var fileSizeString: String {
        let mb = Double(fileSize) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
}
