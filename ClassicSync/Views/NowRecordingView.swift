import SwiftUI

struct NowRecordingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            switch appState.recordingStatus {
            case .idle:
                idleContent
            case .recording(let track):
                recordingContent(track: track)
            case .encoding(let track, let progress):
                encodingContent(track: track, progress: progress)
            case .paused:
                pausedContent
            case .finished:
                finishedContent
            case .failed(let reason):
                failedContent(reason: reason)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - States

    private var idleContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "record.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Ready to Record")
                .font(.title2.bold())
                .foregroundColor(.secondary)
            Text("Add tracks to the queue and press Start")
                .foregroundColor(.secondary)
        }
    }

    private func recordingContent(track: TrackInfo) -> some View {
        VStack(spacing: 20) {
            // Artwork
            artworkView(track: track, size: 180)

            // Track info
            VStack(spacing: 4) {
                Text(track.name)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(track.artist)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(track.album)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            // Recording indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                    .onAppear { pulseScale = 1.4 }
                Text("RECORDING")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }

            // Waveform
            WaveformView(levels: appState.audioLevels)
                .frame(height: 48)
                .padding(.horizontal)

            // Progress
            progressSection(track: track)
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    private func encodingContent(track: TrackInfo, progress: Double) -> some View {
        VStack(spacing: 20) {
            artworkView(track: track, size: 120)
                .opacity(0.7)

            VStack(spacing: 4) {
                Text(track.name).font(.headline).lineLimit(1)
                Text(track.artist).foregroundColor(.secondary).font(.callout)
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Encoding MP3…")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.callout.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                ProgressView(value: progress)
                    .tint(.accentColor)
            }
            .padding(.horizontal)
        }
    }

    private var pausedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Paused")
                .font(.title2.bold())
            if let track = appState.currentTrack {
                Text(track.name).foregroundColor(.secondary)
            }
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Queue Complete")
                .font(.title2.bold())
        }
    }

    private func failedContent(reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text("Recording Failed")
                .font(.title2.bold())
            Text(reason)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Subviews

    private func artworkView(track: TrackInfo, size: CGFloat) -> some View {
        Group {
            if let artwork = track.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.15))
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 12, y: 4)
    }

    private func progressSection(track: TrackInfo) -> some View {
        VStack(spacing: 6) {
            if track.duration > 0 {
                ProgressView(value: min(appState.elapsedTime / track.duration, 1.0))
                    .tint(.accentColor)
                    .padding(.horizontal)
            }
            HStack {
                Text(formatTime(appState.elapsedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Spacer()
                if track.duration > 0 {
                    Text(formatTime(track.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width / CGFloat(levels.count) - 1
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(level: level))
                        .frame(width: max(barWidth, 2),
                               height: max(2, CGFloat(level) * geo.size.height))
                        .animation(.easeOut(duration: 0.05), value: level)
                }
            }
        }
    }

    private func barColor(level: Float) -> Color {
        if level < 0.5 { return .accentColor }
        if level < 0.8 { return .yellow }
        return .red
    }
}
