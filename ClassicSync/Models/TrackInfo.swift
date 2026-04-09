import Foundation
import AppKit

struct TrackInfo: Identifiable, Equatable {
    let id: String          // persistentID from Music.app
    let name: String
    let artist: String
    let album: String
    let albumArtist: String
    let trackNumber: Int
    let discNumber: Int
    let duration: Double    // seconds
    let artwork: NSImage?

    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct Playlist: Identifiable {
    let id: String
    let name: String
    let trackCount: Int
}

enum RecordingStatus: Equatable {
    case idle
    case recording(track: TrackInfo)
    case encoding(track: TrackInfo, progress: Double)
    case paused
    case finished
    case failed(reason: String)
}
