import Foundation
import Combine

/// Orchestrates: AppleScript → play track → capture audio → encode → tag → save.
@MainActor
class RecordingCoordinator: ObservableObject {
    private let appState: AppState
    private let capture = AudioCaptureEngine()
    private let encoder = FFmpegEncoder()
    private let bridge  = AppleScriptBridge()

    private var pollingTimer: Timer?
    private var currentSession: RecordingSession?
    private var isProcessingNext = false

    // Gap between tracks
    private let interTrackGap: TimeInterval = 1.5
    // Minimum captured seconds to save partial recording
    private let minPartialDuration: Double = 30

    init(appState: AppState) {
        self.appState = appState
        capture.delegate = self
    }

    // MARK: - Queue control

    func startQueue() {
        guard !appState.queue.isEmpty else { return }
        guard appState.ffmpegFound else {
            appState.showError("ffmpeg not found. Please install it via Homebrew.")
            return
        }
        guard AudioCaptureEngine.isBlackHoleAvailable() else {
            appState.showError("BlackHole audio device not found. Please complete setup.")
            return
        }
        guard DiskSpaceChecker.hasSufficientSpace(for: appState.queue.count, at: appState.outputFolder) else {
            appState.showError("Insufficient disk space. Each track needs ~30 MB.")
            return
        }
        processNextTrack()
    }

    func pauseQueue() {
        bridge.pausePlayback()
        capture.pauseRecording()
        appState.recordingStatus = .paused
    }

    func resumeQueue() {
        bridge.resumePlayback()
        capture.resumeRecording()
        if let session = currentSession {
            appState.recordingStatus = .recording(track: session.track)
        }
    }

    func skipCurrentTrack() {
        guard let session = currentSession else { return }
        stopCurrentCapture(save: session.capturedDuration > minPartialDuration)
    }

    func stopQueue() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        bridge.stopPlayback()
        if let session = currentSession {
            stopCurrentCapture(save: session.capturedDuration > minPartialDuration)
        }
        appState.recordingStatus = .idle
        isProcessingNext = false
    }

    // MARK: - Track processing

    private func processNextTrack() {
        guard !appState.queue.isEmpty, !isProcessingNext else { return }
        isProcessingNext = true

        let track = appState.queue[0]

        // Duplicate detection
        if FileNamer.isDuplicate(track: track, in: appState.outputFolder) {
            appState.queue.removeFirst()
            isProcessingNext = false
            processNextTrack()
            return
        }

        let session = RecordingSession(track: track)
        currentSession = session
        let tempURL = RecordingSession.makeTempURL(for: track)
        session.tempWAVURL = tempURL

        appState.recordingStatus = .recording(track: track)
        appState.currentTrack = track
        appState.elapsedTime = 0

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // Start capture
            do {
                try await MainActor.run { try self.capture.startRecording(to: tempURL) }
            } catch {
                await MainActor.run { self.appState.showError("Audio capture failed: \(error.localizedDescription)") }
                return
            }

            // Play the track
            self.bridge.playTrack(persistentID: track.id)

            // Fetch artwork in background
            let artwork = self.bridge.getArtwork(for: track.id)
            var artworkData: Data?
            if let img = artwork {
                artworkData = ArtworkResizer.jpegData(from: img)
            }

            await MainActor.run { self.startPolling(session: session, artworkData: artworkData) }
        }
    }

    private func startPolling(session: RecordingSession, artworkData: Data?) {
        pollingTimer?.invalidate()
        var elapsedSeconds: Double = 0

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }

            elapsedSeconds += 0.5
            self.appState.elapsedTime = elapsedSeconds

            // Check if Music.app stopped playing this track
            let position = self.bridge.getPlayerPosition()
            let duration = session.track.duration

            let trackEnded = duration > 0 && position >= (duration - 1.0)
            let musicStopped = !self.bridge.isPlaying() && elapsedSeconds > 2

            if trackEnded || musicStopped {
                timer.invalidate()
                self.pollingTimer = nil
                self.finishTrack(session: session, artworkData: artworkData)
            }
        }
    }

    private func finishTrack(session: RecordingSession, artworkData: Data?) {
        capture.stopRecording()

        guard let tempURL = session.tempWAVURL else {
            isProcessingNext = false
            processNextTrack()
            return
        }

        let outputURL = FileNamer.outputURL(for: session.track, in: appState.outputFolder)
        do { try FileNamer.createDirectories(for: outputURL) } catch {
            appState.showError("Could not create output directory: \(error.localizedDescription)")
            return
        }

        session.outputMP3URL = outputURL
        appState.recordingStatus = .encoding(track: session.track, progress: 0)

        let options = FFmpegEncoder.EncodeOptions(
            inputWAV: tempURL,
            outputMP3: outputURL,
            track: session.track,
            artworkData: artworkData
        )

        encoder.encode(options: options, progress: { [weak self] p in
            guard let self else { return }
            self.appState.recordingStatus = .encoding(track: session.track, progress: p)
        }) { [weak self] result in
            guard let self else { return }
            try? FileManager.default.removeItem(at: tempURL)

            switch result {
            case .success(let mp3URL):
                let size = (try? FileManager.default.attributesOfItem(atPath: mp3URL.path)[.size] as? Int64) ?? 0
                self.appState.markCompleted(session.track, fileURL: mp3URL, fileSize: size, duration: session.track.duration)
                self.isProcessingNext = false
                // Brief gap before next track
                DispatchQueue.main.asyncAfter(deadline: .now() + self.interTrackGap) {
                    self.processNextTrack()
                }
            case .failure(let error):
                self.appState.showError("Encoding failed: \(error.localizedDescription)")
                self.isProcessingNext = false
                self.appState.recordingStatus = .idle
            }
        }
    }

    private func stopCurrentCapture(save: Bool) {
        pollingTimer?.invalidate()
        pollingTimer = nil
        bridge.stopPlayback()
        capture.stopRecording()

        if !save, let url = currentSession?.tempWAVURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentSession = nil
        isProcessingNext = false
    }
}

// MARK: - AudioCaptureDelegate
extension RecordingCoordinator: AudioCaptureDelegate {
    nonisolated func audioCapture(_ engine: AudioCaptureEngine, didReceiveLevels levels: [Float]) {
        Task { @MainActor in appState.audioLevels = levels }
    }

    nonisolated func audioCaptureDeviceDisconnected(_ engine: AudioCaptureEngine) {
        Task { @MainActor in
            appState.showError("BlackHole audio device was disconnected. Recording paused.")
            appState.recordingStatus = .paused
        }
    }
}
