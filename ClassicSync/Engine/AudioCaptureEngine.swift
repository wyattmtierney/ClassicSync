import Foundation
import AVFoundation
import CoreAudio

protocol AudioCaptureDelegate: AnyObject {
    func audioCapture(_ engine: AudioCaptureEngine, didReceiveLevels levels: [Float])
    func audioCaptureDeviceDisconnected(_ engine: AudioCaptureEngine)
}

class AudioCaptureEngine {
    weak var delegate: AudioCaptureDelegate?

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    private let levelUpdateInterval: TimeInterval = 0.05
    private var lastLevelUpdate: Date = .distantPast

    var isRecording: Bool { audioFile != nil }

    // MARK: - Device Detection

    /// Returns the AudioDeviceID for a device whose name contains "BlackHole"
    static func findBlackHoleDeviceID() -> AudioDeviceID? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs) == noErr else { return nil }

        for deviceID in deviceIDs {
            if let name = deviceName(for: deviceID), name.lowercased().contains("blackhole") {
                return deviceID
            }
        }
        return nil
    }

    static func findBlackHoleDeviceName() -> String? {
        guard let id = findBlackHoleDeviceID() else { return nil }
        return deviceName(for: id)
    }

    static func isBlackHoleAvailable() -> Bool {
        findBlackHoleDeviceID() != nil
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name as String
    }

    // MARK: - Recording

    /// Sets the default input device to BlackHole and installs a tap on the input node.
    func startRecording(to url: URL) throws {
        guard let deviceID = Self.findBlackHoleDeviceID() else {
            throw CaptureError.blackHoleNotFound
        }

        outputURL = url

        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Point the engine at the BlackHole device
        try setDefaultInputDevice(deviceID)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Create output WAV file — 44.1 kHz stereo PCM
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: min(format.channelCount, 2),
            interleaved: false
        ) ?? format

        audioFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
    }

    func pauseRecording() {
        audioEngine?.pause()
    }

    func resumeRecording() {
        try? audioEngine?.start()
    }

    // MARK: - Buffer handling

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        // Write samples to file
        try? audioFile?.write(from: buffer)

        // Level metering
        let now = Date()
        guard now.timeIntervalSince(lastLevelUpdate) >= levelUpdateInterval else { return }
        lastLevelUpdate = now

        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let binCount = 40
        var levels = [Float](repeating: 0, count: binCount)
        let framesPerBin = max(1, frameCount / binCount)

        for bin in 0..<binCount {
            let start = bin * framesPerBin
            let end = min(start + framesPerBin, frameCount)
            var sum: Float = 0
            for frame in start..<end {
                sum += abs(channelData[0][frame])
            }
            levels[bin] = sum / Float(framesPerBin)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.audioCapture(self, didReceiveLevels: levels)
        }
    }

    // MARK: - CoreAudio helpers

    private func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        if status != noErr { throw CaptureError.couldNotSetDevice(status) }
    }

    enum CaptureError: LocalizedError {
        case blackHoleNotFound
        case couldNotSetDevice(OSStatus)

        var errorDescription: String? {
            switch self {
            case .blackHoleNotFound: return "BlackHole audio device not found."
            case .couldNotSetDevice(let s): return "Could not set input device (OSStatus \(s))."
            }
        }
    }
}
