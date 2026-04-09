import Foundation

enum FileNamer {
    private static let illegalChars = CharacterSet(charactersIn: "/\\:*?\"<>|")

    static func safeName(_ string: String) -> String {
        string.components(separatedBy: illegalChars).joined(separator: "_")
    }

    /// Artist/Album/TrackNumber - Title.mp3
    static func outputURL(for track: TrackInfo, in folder: URL) -> URL {
        let artist = safeName(track.albumArtist.isEmpty ? track.artist : track.albumArtist)
        let album  = safeName(track.album)
        let title  = safeName(track.name)
        let num    = track.trackNumber > 0 ? String(format: "%02d - ", track.trackNumber) : ""
        let filename = "\(num)\(title).mp3"
        return folder
            .appendingPathComponent(artist, isDirectory: true)
            .appendingPathComponent(album, isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func createDirectories(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Returns true if the output file already exists (duplicate detection)
    static func isDuplicate(track: TrackInfo, in folder: URL) -> Bool {
        let url = outputURL(for: track, in: folder)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
