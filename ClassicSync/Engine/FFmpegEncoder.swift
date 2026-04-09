import Foundation

class FFmpegEncoder {

    // MARK: - Discovery

    static func findFFmpegPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Try `which ffmpeg`
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["ffmpeg"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        return nil
    }

    static func isAvailable() -> Bool { findFFmpegPath() != nil }

    // MARK: - Encoding

    struct EncodeOptions {
        let inputWAV: URL
        let outputMP3: URL
        let track: TrackInfo
        let artworkData: Data?
        let bitrate: Int = 320

        /// ffmpeg metadata args for ID3v2.3 tags
        var metadataArgs: [String] {
            var args: [String] = []
            func add(_ key: String, _ value: String) {
                guard !value.isEmpty else { return }
                args += ["-metadata", "\(key)=\(value)"]
            }
            add("title",  track.name)
            add("artist", track.artist)
            add("album",  track.album)
            add("album_artist", track.albumArtist)
            if track.trackNumber > 0 { add("track", "\(track.trackNumber)") }
            if track.discNumber  > 0 { add("disc",  "\(track.discNumber)") }
            return args
        }
    }

    /// Encodes WAV → MP3. Progress 0…1 is reported via the callback.
    func encode(
        options: EncodeOptions,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let ffmpeg = Self.findFFmpegPath() else {
            completion(.failure(EncodeError.ffmpegNotFound))
            return
        }

        // Write artwork to temp file if present
        var artworkTmpURL: URL?
        if let data = options.artworkData {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("classicsync_art_\(UUID().uuidString).jpg")
            try? data.write(to: tmp)
            artworkTmpURL = tmp
        }

        var args = ["-y", "-i", options.inputWAV.path]

        // Attach artwork as second input if available
        if let artURL = artworkTmpURL {
            args += ["-i", artURL.path,
                     "-map", "0:a", "-map", "1:v",
                     "-c:v", "copy",
                     "-id3v2_version", "3",
                     "-metadata:s:v", "title=Album cover",
                     "-metadata:s:v", "comment=Cover (Front)"]
        } else {
            args += ["-id3v2_version", "3"]
        }

        args += options.metadataArgs
        args += ["-codec:a", "libmp3lame",
                 "-b:a", "\(options.bitrate)k",
                 "-ar", "44100",
                 "-ac", "2",
                 options.outputMP3.path]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: ffmpeg)
        task.arguments = args

        // ffmpeg writes progress to stderr
        let stderrPipe = Pipe()
        task.standardError = stderrPipe
        task.standardOutput = Pipe() // discard stdout

        let duration = options.track.duration

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }
            // Parse "time=HH:MM:SS.ms" from ffmpeg output
            if let timeStr = Self.parseTime(from: text), duration > 0 {
                let p = min(timeStr / duration, 1.0)
                DispatchQueue.main.async { progress(p) }
            }
        }

        task.terminationHandler = { t in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            if let tmp = artworkTmpURL { try? FileManager.default.removeItem(at: tmp) }
            DispatchQueue.main.async {
                if t.terminationStatus == 0 {
                    completion(.success(options.outputMP3))
                } else {
                    completion(.failure(EncodeError.ffmpegFailed(t.terminationStatus)))
                }
            }
        }

        do {
            try task.run()
        } catch {
            completion(.failure(error))
        }
    }

    private static func parseTime(from text: String) -> Double? {
        // Match "time=HH:MM:SS.ss"
        guard let range = text.range(of: #"time=(\d+):(\d+):(\d+\.\d+)"#, options: .regularExpression) else { return nil }
        let match = String(text[range]).dropFirst(5) // remove "time="
        let parts = match.split(separator: ":").map { Double($0) ?? 0 }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    enum EncodeError: LocalizedError {
        case ffmpegNotFound
        case ffmpegFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound: return "ffmpeg not found. Install via: brew install ffmpeg"
            case .ffmpegFailed(let code): return "ffmpeg exited with code \(code)."
            }
        }
    }
}
