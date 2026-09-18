# JemWallpaperConverter

A standalone, lightweight macOS tool to convert any `.mp4` or `.mov` video into a macOS wallpaper-compatible QuickTime `.mov` file with full QuickTime atom injection (`csgm`, `sgpd`, `tapt`, `cslg`) and vendor tag sanitization.

> **Based on [OpenLiveWalls](https://github.com/bl33dz/OpenLiveWalls) by [bl33dz](https://github.com/bl33dz)** — the QuickTime atom patching logic, HEVC encoding pipeline, and wallpaper compatibility approach were extracted and adapted from that project. See [Attribution](#attribution) for details.

---

## Features

- **Drag & Drop GUI**: Simply drop any `.mp4` or `.mov` video onto the window (or click "Browse Files...").
- **Wallpaper Compatibility**: Automatically encodes with `libx265` HEVC 10-bit (`yuv420p10le`), `hvc1` tag, keyframe interval 60, bt709 color profiles, and injects the required QuickTime atoms (`csgm`, `sgpd`, `tapt`, `cslg`).
- **Vendor Tag Sanitization**: Removes `FFMP` vendor tags from QuickTime headers.
- **Customizable Options**:
  - Quality (CRF slider: default 18)
  - Speed Preset (ultrafast to slow: default medium)
  - Audio track toggle — preserve or remove audio (audio removed by default for clean wallpaper files)
  - Custom destination folder selection or output file naming
- **Live Logs & Progress**: Visual stage progression (Encoding → Patching Atoms → Validating → Complete) and live console output.
- **Quick Finder Reveal**: One-click "Reveal in Finder" button when conversion finishes.
- **CLI Support**: Scriptable command-line interface for batch jobs or terminal workflows.

---

## Prerequisites

- **macOS 14.0+** (macOS Sonoma, Sequoia, or later)
- **ffmpeg with libx265**:
  ```sh
  brew install ffmpeg
  ```
  The app automatically finds `ffmpeg` at `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, or in your `PATH`.

---

## Getting Started

### 1. Build the App Bundle

To build the standalone `JemWallpaperConverter.app`:

```sh
cd JemWallpaperConverter
./build.sh
```

This compiles the release binary, creates the macOS application bundle, and ad-hoc signs it.

### 2. Launch the GUI

Double-click `JemWallpaperConverter.app` in Finder, or run:

```sh
open JemWallpaperConverter.app
```

Then drag and drop your `.mp4` or `.mov` file into the window and click **Convert to Wallpaper MOV**!

---

## Command Line Usage (CLI)

`JemWallpaperConverter` can also run headlessly directly from terminal:

```sh
# Basic usage (outputs <name>-wallpaper.mov in the same folder)
./JemWallpaperConverter.app/Contents/MacOS/JemWallpaperConverter input.mp4

# Specify custom output path
./JemWallpaperConverter.app/Contents/MacOS/JemWallpaperConverter input.mp4 output.mov

# Specify advanced flags
./JemWallpaperConverter.app/Contents/MacOS/JemWallpaperConverter --src input.mp4 --dst wallpaper.mov --crf 16 --preset fast
```

### CLI Arguments

| Flag | Description | Default |
|:-----|:------------|:--------|
| `<input>` | Input video path (`.mp4`, `.mov`) | *Required* |
| `<output>` / `-o` / `--dst` | Output `.mov` path | `<input>-wallpaper.mov` |
| `--crf <int>` | Constant Rate Factor (lower = higher quality) | `18` |
| `--preset <name>` | x265 encoding speed preset | `medium` |
| `--keep-audio` | Keep audio track (by default audio is removed) | `false` |
| `-h` / `--help` | Show help and usage instructions | |

---

## Project Structure

```
JemWallpaperConverter/
├── Package.swift               # Swift Package Manager definition
├── build.sh                    # One-step build and bundle script
├── README.md                   # Documentation
├── Bundle/
│   ├── Info.plist              # Application bundle configuration
│   └── AppIcon.icns            # App icon
└── Sources/
    ├── main.swift              # Dual-mode entry point (CLI / GUI)
    ├── Core/
    │   └── WallpaperConverter.swift # Conversion engine (ffmpeg + atom injection)
    ├── UI/
    │   ├── ContentView.swift   # Drag-and-drop SwiftUI interface
    │   └── ConverterViewModel.swift # App state and file handling
    └── QtParser/               # Self-contained QuickTime atom parser & injector
        ├── QtAtomPatcher.swift
        ├── WallpaperInjector.swift
        ├── QtDefaultRegistry.swift
        ├── Analyzers/
        ├── Atoms/
        ├── Core/
        └── Generators/
```

---

## Attribution

This project is based on and extracted from **[OpenLiveWalls](https://github.com/bl33dz/OpenLiveWalls)** by [bl33dz](https://github.com/bl33dz).

> **OpenLiveWalls** — *Open-source live video wallpapers for macOS — local, private, hackable.*  
> Licensed under the [GNU General Public License v3.0 (GPLv3)](https://github.com/bl33dz/OpenLiveWalls/blob/main/LICENSE).

The following core components were adapted from OpenLiveWalls:

| Component | Source |
|:----------|:-------|
| QuickTime atom patching logic (`csgm`, `sgpd`, `tapt`, `cslg`) | `QtParser/` module |
| HEVC/libx265 encoding pipeline with wallpaper-compatible settings | `WallpaperConverter.swift` |
| Vendor tag (`FFMP`) removal from QuickTime headers | `WallpaperConverter.swift` |
| bt709 color profile settings and `hvc1` tagging | `WallpaperConverter.swift` |

JemWallpaperConverter is a standalone spinoff that packages this conversion pipeline as a dedicated single-purpose macOS app with a drag-and-drop GUI and CLI interface, without the full menu bar wallpaper player functionality of the original.

In accordance with the GPLv3 license, this project is also open-source. Full credit goes to **bl33dz** and the OpenLiveWalls project for the foundational work.
