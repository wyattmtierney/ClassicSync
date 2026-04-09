import Foundation

class RecordingSession {
    let track: TrackInfo
    let startedAt: Date
    var tempWAVURL: URL?
    var outputMP3URL: URL?
    var capturedSamples: Int = 0
    var sampleRate: Double = 44100

    var capturedDuration: Double {
        Double(capturedSamples) / sampleRate
    }

    init(track: TrackInfo) {
        self.track = track
        self.startedAt = Date()
    }

    static func makeTempURL(for track: TrackInfo) -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let safe = FileNamer.safeName(track.name)
        return tmp.appendingPathComponent("classicsync_\(safe)_\(UUID().uuidString).wav")
    }
}
