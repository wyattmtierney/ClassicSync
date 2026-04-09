import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: SetupStep = .checkingDeps
    @State private var installOutput: String = ""
    @State private var isInstalling = false

    enum SetupStep: Int, CaseIterable {
        case checkingDeps, installBlackHole, installFFmpeg, configureAudio, done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hifi.speaker.2")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("ClassicSync Setup")
                        .font(.title.bold())
                    Text("Record Apple Music to MP3 for your iPod Classic")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepRow(
                        number: 1,
                        title: "BlackHole Virtual Audio Driver",
                        subtitle: "Routes audio from Music.app to ClassicSync for recording",
                        status: appState.blackHoleFound ? .done : (step == .installBlackHole ? .active : .waiting)
                    ) {
                        if !appState.blackHoleFound {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("BlackHole is a free virtual audio driver that creates a loopback device.")
                                    .foregroundColor(.secondary)
                                Button(action: installBlackHole) {
                                    Label("Install via Homebrew", systemImage: "terminal")
                                }
                                .disabled(isInstalling)
                                if !installOutput.isEmpty {
                                    Text(installOutput)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }

                    stepRow(
                        number: 2,
                        title: "ffmpeg",
                        subtitle: "Converts captured audio to 320 kbps MP3 with ID3 tags",
                        status: appState.ffmpegFound ? .done : (step == .installFFmpeg ? .active : .waiting)
                    ) {
                        if !appState.ffmpegFound {
                            Button(action: installFFmpeg) {
                                Label("Install via Homebrew", systemImage: "terminal")
                            }
                            .disabled(isInstalling)
                        }
                    }

                    stepRow(
                        number: 3,
                        title: "Multi-Output Audio Device",
                        subtitle: "Route sound through BlackHole while keeping your speakers active",
                        status: step.rawValue >= SetupStep.configureAudio.rawValue ? .active : .waiting
                    ) {
                        AudioRouteDiagram()
                        Button("Open Audio MIDI Setup") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app"))
                        }
                        Text("Create a Multi-Output Device with both your speakers and BlackHole 2ch as outputs, then set it as your default output in System Settings → Sound.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Spacer()
                Button("Continue") {
                    appState.isSetupComplete = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.blackHoleFound || !appState.ffmpegFound)
                .padding()
            }
            .background(.regularMaterial)
        }
        .onAppear(perform: checkDependencies)
    }

    // MARK: - Helpers

    private func checkDependencies() {
        appState.blackHoleFound = AudioCaptureEngine.isBlackHoleAvailable()
        if let path = FFmpegEncoder.findFFmpegPath() {
            appState.ffmpegFound = true
            appState.ffmpegPath = path
        }
        step = !appState.blackHoleFound ? .installBlackHole :
               !appState.ffmpegFound   ? .installFFmpeg : .configureAudio
    }

    private func installBlackHole() {
        runBrew(["install", "blackhole-2ch"]) {
            self.appState.blackHoleFound = AudioCaptureEngine.isBlackHoleAvailable()
            if self.appState.blackHoleFound { self.step = .installFFmpeg }
        }
    }

    private func installFFmpeg() {
        runBrew(["install", "ffmpeg"]) {
            if let path = FFmpegEncoder.findFFmpegPath() {
                self.appState.ffmpegFound = true
                self.appState.ffmpegPath = path
                self.step = .configureAudio
            }
        }
    }

    private func runBrew(_ args: [String], completion: @escaping () -> Void) {
        isInstalling = true
        installOutput = "Running brew \(args.joined(separator: " "))…"

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
                ? "/opt/homebrew/bin/brew" : "/usr/local/bin/brew"
            task.executableURL = URL(fileURLWithPath: brewPath)
            task.arguments = args
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self.installOutput = output
                self.isInstalling = false
                completion()
            }
        }
    }

    @ViewBuilder
    private func stepRow<Content: View>(
        number: Int,
        title: String,
        subtitle: String,
        status: StepStatus,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                if status == .done {
                    Image(systemName: "checkmark")
                        .foregroundColor(status.color)
                        .fontWeight(.bold)
                } else {
                    Text("\(number)")
                        .foregroundColor(status.color)
                        .fontWeight(.semibold)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).fontWeight(.semibold)
                    Spacer()
                    if status == .done {
                        Text("Installed").foregroundColor(.green).font(.caption)
                    }
                }
                Text(subtitle).foregroundColor(.secondary).font(.callout)
                if status != .waiting {
                    content()
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(status == .active ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(status == .active ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2)))
    }

    enum StepStatus { case waiting, active, done
        var color: Color {
            switch self { case .waiting: return .secondary; case .active: return .accentColor; case .done: return .green }
        }
    }
}

struct AudioRouteDiagram: View {
    var body: some View {
        HStack(spacing: 8) {
            diagramBox("Music.app", icon: "music.note", color: .pink)
            arrow
            diagramBox("Multi-Output\nDevice", icon: "speaker.wave.3", color: .blue)
            VStack(spacing: 4) {
                arrow
                arrow
            }
            VStack(spacing: 8) {
                diagramBox("BlackHole 2ch\n(ClassicSync reads)", icon: "waveform", color: .purple)
                diagramBox("Speakers / Headphones", icon: "speaker.fill", color: .green)
            }
        }
        .font(.caption)
        .padding(12)
        .background(Color.black.opacity(0.03))
        .cornerRadius(8)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").foregroundColor(.secondary)
    }

    private func diagramBox(_ label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text(label).multilineTextAlignment(.center).foregroundColor(.primary)
        }
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
