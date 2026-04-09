# ClassicSync

> Record Apple Music tracks in real-time and convert them to high-quality MP3s — built for the iPod Classic.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/status-in%20development-yellow?style=flat-square)

---

## What It Does

Apple Music tracks are protected by FairPlay DRM, which prevents direct file extraction. ClassicSync works around this by capturing the decoded audio stream in real-time using [BlackHole](https://existential.audio/blackhole/) — a free macOS virtual audio driver — and encoding it to a 320kbps MP3 with full metadata and high-resolution album artwork embedded.

The result is a clean, iPod Classic-ready MP3 library organized by Artist → Album, with ID3v2.3 tags, embedded 3000×3000 JPEG artwork, and audio quality indistinguishable from the source.

---

## Features

- **Real-time audio capture** via BlackHole loopback — no DRM circumvention, no grey-area tools
- **320kbps CBR MP3** encoded with LAME at highest quality settings
- **High-resolution artwork** — fetches up to 3000×3000px from MusicKit with local cache fallback
- **Full ID3v2.3 metadata** — title, artist, album artist, track/disc numbers, year, genre, composer, BPM
- **iPod Classic compatibility** — ID3v2.3 + v1 tags, JPEG artwork capped at 3000px, safe filenames
- **Queue-based recording** — build a queue from your Music.app playlists, walk away
- **Auto track splitting** — detects track boundaries via AppleScript, splits and names files automatically
- **Quality verification** — ffprobe validates every encoded file before marking complete
- **Output folder structure**: `Artist/Album/TrackNumber - Title.mp3`

---

## Requirements

| Dependency | Install | Purpose |
|---|---|---|
| macOS 13 Ventura+ | — | Required OS |
| [BlackHole 2ch](https://existential.audio/blackhole/) | `brew install blackhole-2ch` | Virtual audio loopback |
| [ffmpeg](https://ffmpeg.org/) | `brew install ffmpeg` | MP3 encoding |
| Apple Music subscription | — | Source audio |
| Xcode 15+ | App Store | Build the app |

ClassicSync will check for BlackHole and ffmpeg on first launch and guide you through installation if either is missing.

---

## How It Works

```
Apple Music.app
      │
      │  plays audio
      ▼
BlackHole 2ch (virtual audio device)
      │
      │  raw PCM stream (44.1kHz / 32-bit float / stereo)
      ▼
AVAudioEngine (ClassicSync captures here)
      │
      │  buffers audio per track
      ▼
ffmpeg (LAME encoder)
      │
      │  320kbps CBR MP3 + ID3v2.3 tags + embedded artwork
      ▼
~/Music/ClassicSync/Artist/Album/01 - Title.mp3
```

AppleScript polls Music.app every 500ms to detect track changes, capture metadata, and trigger track splits. MusicKit fetches artwork at the highest available resolution from Apple's CDN.

---

## Setup

### 1. Install Dependencies

```bash
brew install blackhole-2ch ffmpeg
```

### 2. Create a Multi-Output Device

This lets your Mac play audio through your speakers *and* send a copy to BlackHole simultaneously.

1. Open **Audio MIDI Setup** (`/Applications/Utilities/Audio MIDI Setup.app`)
2. Click **+** in the bottom left → **Create Multi-Output Device**
3. Check **BlackHole 2ch** and your speakers/headphones
4. Rename it to something like `ClassicSync Output`
5. Set your **System Output** to this new Multi-Output Device

> ClassicSync's setup screen walks you through this with a visual diagram.

### 3. Build & Run

```bash
git clone https://github.com/yourusername/ClassicSync.git
cd ClassicSync
open ClassicSync.xcodeproj
```

Build and run in Xcode. On first launch, grant Music.app AppleScript access and MusicKit permission when prompted.

---

## Usage

1. **Launch ClassicSync** — setup wizard confirms BlackHole and ffmpeg are ready
2. **Build a queue** — browse your Music.app playlists and add tracks
3. **Choose output folder** — defaults to `~/Music/ClassicSync/`
4. **Hit Record** — ClassicSync plays each track through Music.app and captures the audio
5. **Walk away** — the queue runs automatically, splitting and encoding each track
6. **Drag to iTunes/Finder** — sync your completed MP3s to your iPod Classic

---

## Output Spec

| Property | Value |
|---|---|
| Format | MP3 |
| Bitrate | 320kbps CBR |
| Sample rate | 44,100 Hz |
| Channels | Stereo (joint stereo) |
| Encoder | LAME (`-q:a 0`) |
| Tags | ID3v2.3 + ID3v1 |
| Artwork | JPEG, up to 3000×3000px |
| Folder structure | `Artist/Album/NN - Title.mp3` |

---

## Project Structure

```
ClassicSync/
├── App/
│   ├── ClassicSyncApp.swift
│   └── ContentView.swift
├── Engine/
│   ├── AudioCaptureEngine.swift     # CoreAudio + AVAudioEngine tap
│   ├── FFmpegEncoder.swift          # ffmpeg process wrapper + quality verification
│   └── AppleScriptBridge.swift      # Music.app control + metadata fetch
├── Models/
│   ├── TrackInfo.swift
│   ├── RecordingSession.swift
│   └── AppState.swift
├── Views/
│   ├── SetupView.swift              # First-launch dependency wizard
│   ├── QueueView.swift              # Playlist browser + recording queue
│   ├── NowRecordingView.swift       # Live waveform + progress
│   └── CompletedView.swift          # Encoded file list with quality badges
└── Utilities/
    ├── FileNamer.swift              # Safe filename generation
    ├── ArtworkResizer.swift         # MusicKit HD fetch + JPEG processing
    └── DiskSpaceChecker.swift       # Pre-queue space estimation
```

---

## Known Limitations

- **Real-time only** — recording takes as long as the music plays. A 4-minute track takes 4 minutes.
- **Requires active playback** — Music.app must be the audio source; other system audio will bleed into the recording if playing simultaneously.
- **Apple Music subscription required** — purchased iTunes Store tracks (post-2009) are DRM-free AAC and don't need this workflow.
- **System audio must route through BlackHole** — notifications, video, etc. will be captured too. Silence other audio sources while recording.

---

## Legal

ClassicSync does not circumvent, decrypt, or reverse-engineer Apple's FairPlay DRM. It captures audio at the system output level — the same decoded audio your speakers receive — using a licensed virtual audio driver. This is analogous to recording from a line-out jack.

Use ClassicSync only with music you have the right to play. Recording Apple Music tracks for redistribution violates Apple's Terms of Service and copyright law. This tool is intended for personal, private use.

---

## Roadmap

- [ ] Core recording engine (Phase 1)
- [ ] High-res artwork + full metadata pipeline (Phase 2)
- [ ] Waveform visualizer
- [ ] Duplicate detection (skip already-encoded tracks)
- [ ] Menu bar recording indicator
- [ ] Estimated queue completion time
- [ ] Direct iPod sync via libimobiledevice (stretch goal)

---

## Contributing

Pull requests welcome. If you hit a bug with a specific Music.app version or macOS release, please open an issue with your macOS version, Music.app version, and the ffprobe output from the problematic file.

---

## Acknowledgements

- [BlackHole](https://github.com/ExistentialAudio/BlackHole) by Existential Audio — the backbone of the capture pipeline
- [LAME](https://lame.sourceforge.io/) — MP3 encoding
- [ffmpeg](https://ffmpeg.org/) — encoding pipeline and quality verification

---

*Built for the people who still think the click wheel was peak UI.*
