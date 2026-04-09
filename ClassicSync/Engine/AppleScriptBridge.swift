import Foundation
import AppKit

/// Wrapper around Music.app AppleScript commands.
/// All methods run synchronously — call off the main thread.
class AppleScriptBridge {

    // MARK: - Track Info

    func getCurrentTrack() -> TrackInfo? {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set t to current track
                set tName to name of t
                set tArtist to artist of t
                set tAlbum to album of t
                set tAlbumArtist to album artist of t
                set tTrackNum to track number of t
                set tDiscNum to disc number of t
                set tDuration to duration of t
                set tID to persistent ID of t
                return tID & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & tAlbumArtist & "||" & (tTrackNum as string) & "||" & (tDiscNum as string) & "||" & (tDuration as string)
            else
                return ""
            end if
        end tell
        """
        guard let result = runAppleScript(script), !result.isEmpty else { return nil }
        let parts = result.components(separatedBy: "||")
        guard parts.count >= 8 else { return nil }
        return TrackInfo(
            id:          parts[0],
            name:        parts[1],
            artist:      parts[2],
            album:       parts[3],
            albumArtist: parts[4],
            trackNumber: Int(parts[5]) ?? 0,
            discNumber:  Int(parts[6]) ?? 0,
            duration:    Double(parts[7]) ?? 0,
            artwork:     nil
        )
    }

    func getPlayerPosition() -> Double {
        let script = """
        tell application "Music"
            return player position as string
        end tell
        """
        guard let r = runAppleScript(script) else { return 0 }
        return Double(r) ?? 0
    }

    func playTrack(persistentID: String) {
        let script = """
        tell application "Music"
            set results to (every track of library playlist 1 whose persistent ID is "\(persistentID)")
            if (count of results) > 0 then
                play (item 1 of results)
            end if
        end tell
        """
        _ = runAppleScript(script)
    }

    func pausePlayback() {
        _ = runAppleScript("""tell application "Music" to pause""")
    }

    func resumePlayback() {
        _ = runAppleScript("""tell application "Music" to play""")
    }

    func stopPlayback() {
        _ = runAppleScript("""tell application "Music" to stop""")
    }

    func isPlaying() -> Bool {
        let script = """
        tell application "Music"
            return (player state is playing) as string
        end tell
        """
        return runAppleScript(script) == "true"
    }

    // MARK: - Library

    func getLibraryPlaylists() -> [Playlist] {
        let script = """
        tell application "Music"
            set output to ""
            repeat with p in user playlists
                set pName to name of p
                set pID to persistent ID of p
                set pCount to count of tracks of p
                set output to output & pID & "||" & pName & "||" & (pCount as string) & "\n"
            end repeat
            return output
        end tell
        """
        guard let result = runAppleScript(script) else { return [] }
        return result.components(separatedBy: "\n").compactMap { line -> Playlist? in
            let parts = line.components(separatedBy: "||")
            guard parts.count >= 3 else { return nil }
            return Playlist(id: parts[0], name: parts[1], trackCount: Int(parts[2]) ?? 0)
        }
    }

    func getTracksInPlaylist(id: String) -> [TrackInfo] {
        let script = """
        tell application "Music"
            set output to ""
            set target to (first user playlist whose persistent ID is "\(id)")
            repeat with t in tracks of target
                set tID to persistent ID of t
                set tName to name of t
                set tArtist to artist of t
                set tAlbum to album of t
                set tAlbumArtist to album artist of t
                set tTrackNum to track number of t
                set tDiscNum to disc number of t
                set tDuration to duration of t
                set output to output & tID & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & tAlbumArtist & "||" & (tTrackNum as string) & "||" & (tDiscNum as string) & "||" & (tDuration as string) & "\n"
            end repeat
            return output
        end tell
        """
        guard let result = runAppleScript(script) else { return [] }
        return result.components(separatedBy: "\n").compactMap { line -> TrackInfo? in
            let parts = line.components(separatedBy: "||")
            guard parts.count >= 8 else { return nil }
            return TrackInfo(
                id:          parts[0],
                name:        parts[1],
                artist:      parts[2],
                album:       parts[3],
                albumArtist: parts[4],
                trackNumber: Int(parts[5]) ?? 0,
                discNumber:  Int(parts[6]) ?? 0,
                duration:    Double(parts[7]) ?? 0,
                artwork:     nil
            )
        }.filter { !$0.id.isEmpty }
    }

    // MARK: - Artwork

    func getArtwork(for persistentID: String) -> NSImage? {
        let script = """
        tell application "Music"
            set results to (every track of library playlist 1 whose persistent ID is "\(persistentID)")
            if (count of results) = 0 then return ""
            set t to item 1 of results
            if (count of artworks of t) = 0 then return ""
            set art to data of artwork 1 of t
            return art
        end tell
        """
        // Artwork must be fetched differently — use NSAppleScript to get raw data
        return fetchArtworkViaAppleScript(persistentID: persistentID)
    }

    private func fetchArtworkViaAppleScript(persistentID: String) -> NSImage? {
        // Write artwork to a temp file via AppleScript
        let tmpPath = NSTemporaryDirectory() + "classicsync_art_\(persistentID).jpg"
        let script = """
        tell application "Music"
            set results to (every track of library playlist 1 whose persistent ID is "\(persistentID)")
            if (count of results) = 0 then return false
            set t to item 1 of results
            if (count of artworks of t) = 0 then return false
            set artData to raw data of artwork 1 of t
            set f to open for access POSIX file "\(tmpPath)" with write permission
            set eof f to 0
            write artData to f
            close access f
            return true
        end tell
        """
        guard let result = runAppleScript(script), result == "true" else { return nil }
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        return NSImage(contentsOfFile: tmpPath)
    }

    // MARK: - Private

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        guard let result = script?.executeAndReturnError(&error) else {
            if let e = error { NSLog("AppleScript error: \(e)") }
            return nil
        }
        return result.stringValue
    }
}
