import SwiftUI
import AppKit

// Check if run in CLI mode
let args = CommandLine.arguments

func printUsage() {
    print("""
    JemWallpaperConverter - Convert MP4/MOV videos to macOS wallpaper-compatible MOV
    
    Usage (CLI):
        JemWallpaperConverter <input-video> [output-video.mov]
        JemWallpaperConverter --src <input-video> --dst <output-video.mov> [--crf 18] [--preset medium] [--keep-audio]
    
    Usage (GUI):
        JemWallpaperConverter
        (Run without arguments to launch the Drag & Drop GUI)
    """)
}

var isCLIMode = false
var inputPath: String?
var outputPath: String?
var crfValue: Int = 18
var presetValue: String = "medium"
var stripAudioValue: Bool = true

if args.count > 1 && !args[1].starts(with: "-psn") { // macOS passes -psn_* when launching from Finder
    isCLIMode = true

    if args.contains("-h") || args.contains("--help") {
        printUsage()
        exit(0)
    }

    var i = 1
    while i < args.count {
        let arg = args[i]
        if arg == "--src" && i + 1 < args.count {
            inputPath = args[i + 1]
            i += 2
        } else if (arg == "--dst" || arg == "-o") && i + 1 < args.count {
            outputPath = args[i + 1]
            i += 2
        } else if arg == "--crf" && i + 1 < args.count {
            crfValue = Int(args[i + 1]) ?? 18
            i += 2
        } else if arg == "--preset" && i + 1 < args.count {
            presetValue = args[i + 1]
            i += 2
        } else if arg == "--keep-audio" {
            stripAudioValue = false
            i += 1
        } else if !arg.starts(with: "-") && inputPath == nil {
            inputPath = arg
            i += 1
        } else if !arg.starts(with: "-") && outputPath == nil {
            outputPath = arg
            i += 1
        } else {
            i += 1
        }
    }
}

if isCLIMode, let inPath = inputPath {
    let inputURL = URL(fileURLWithPath: inPath)
    let outputURL: URL
    if let outPath = outputPath {
        outputURL = URL(fileURLWithPath: outPath)
    } else {
        outputURL = WallpaperConverter.defaultOutputURL(for: inputURL)
    }

    print("═══════════════════════════════════════════════════════════════")
    print(" Jem Wallpaper Converter (CLI)")
    print("═══════════════════════════════════════════════════════════════")
    print("Input:       \(inputURL.path)")
    print("Output:      \(outputURL.path)")
    print("CRF:         \(crfValue)")
    print("Preset:      \(presetValue)")
    print("Strip Audio: \(stripAudioValue)")
    print("───────────────────────────────────────────────────────────────")

    let converter = WallpaperConverter()
    let options = ConversionOptions(
        crf: crfValue,
        preset: presetValue,
        stripAudio: stripAudioValue,
        keyint: 60
    )

    do {
        _ = try converter.convert(
            sourceURL: inputURL,
            destinationURL: outputURL,
            options: options,
            onPhaseChanged: { phase in
                switch phase {
                case .encoding:
                    print("▶ Phase: Encoding HEVC...")
                case .patchingAtoms:
                    print("▶ Phase: Patching QuickTime Atoms...")
                case .validating:
                    print("▶ Phase: Validating required atoms...")
                case .completed(let url):
                    print("★ Phase: Completed -> \(url.path)")
                case .cancelled:
                    print("Phase: Cancelled")
                case .failed(let err):
                    print("Phase: Failed -> \(err)")
                case .idle:
                    break
                }
            },
            onLog: { log in
                print("[Log] \(log)")
            }
        )
        exit(0)
    } catch {
        print("❌ Conversion failed: \(error.localizedDescription)")
        exit(1)
    }
}

// GUI Mode
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let contentView = ContentView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Jem Wallpaper Converter"
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
