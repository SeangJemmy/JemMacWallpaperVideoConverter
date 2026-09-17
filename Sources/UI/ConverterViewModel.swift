import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

public struct VideoFileInfo: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let fileName: String
    public let fileSizeString: String
    public let resolution: String?
    public let durationString: String?
}

@MainActor
public final class ConverterViewModel: ObservableObject {
    @Published public var selectedFile: VideoFileInfo?
    @Published public var customOutputDirectory: URL?
    @Published public var outputFileName: String = ""
    @Published public var isTargeted: Bool = false

    // Options
    @Published public var crf: Double = 18
    @Published public var preset: String = "medium"
    @Published public var stripAudio: Bool = true
    @Published public var showAdvancedSettings: Bool = false

    // State
    @Published public var phase: ConversionPhase = .idle
    @Published public var isConverting: Bool = false
    @Published public var logs: [String] = []
    @Published public var isLogExpanded: Bool = true
    @Published public var errorMessage: String?
    @Published public var completedURL: URL?
    @Published public var elapsedSeconds: Int = 0

    public let presets = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow"]

    private var converter = WallpaperConverter()
    private var timer: Timer?

    public init() {}

    public var effectiveOutputURL: URL? {
        guard let input = selectedFile?.url else { return nil }
        let dir = customOutputDirectory ?? input.deletingLastPathComponent()
        let name = outputFileName.isEmpty ? WallpaperConverter.safeFileName(for: input.deletingPathExtension().lastPathComponent) + "-wallpaper" : outputFileName
        let cleanName = name.hasSuffix(".mov") ? name : "\(name).mov"
        return dir.appendingPathComponent(cleanName)
    }

    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        let typeIdentifiers = [
            UTType.movie.identifier,
            UTType.mpeg4Movie.identifier,
            UTType.quickTimeMovie.identifier,
            UTType.fileURL.identifier
        ]

        for typeId in typeIdentifiers {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] item, _ in
                    guard let self = self else { return }
                    var url: URL?

                    if let data = item as? Data, let decodedURL = URL(dataRepresentation: data, relativeTo: nil) {
                        url = decodedURL
                    } else if let fileURL = item as? URL {
                        url = fileURL
                    }

                    if let validURL = url {
                        Task { @MainActor in
                            self.loadFile(url: validURL)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    public func selectFileViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Select Video"

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    public func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Output Folder"

        if panel.runModal() == .OK, let url = panel.url {
            customOutputDirectory = url
        }
    }

    public func resetOutputDirectory() {
        customOutputDirectory = nil
    }

    public func loadFile(url: URL) {
        let path = url.path
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: path)
        let sizeBytes = (attrs?[.size] as? Int64) ?? 0
        let sizeString = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        let baseName = url.deletingPathExtension().lastPathComponent

        outputFileName = "\(WallpaperConverter.safeFileName(for: baseName))-wallpaper.mov"
        completedURL = nil
        errorMessage = nil
        phase = .idle

        // Fetch video dimensions & duration asynchronously
        let asset = AVURLAsset(url: url)
        Task {
            var resolutionStr: String?
            var durationStr: String?

            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                if let size = try? await track.load(.naturalSize) {
                    resolutionStr = "\(Int(size.width)) × \(Int(size.height))"
                }
            }

            if let duration = try? await asset.load(.duration) {
                let seconds = Int(CMTimeGetSeconds(duration))
                let mins = seconds / 60
                let remSecs = seconds % 60
                durationStr = String(format: "%02d:%02d", mins, remSecs)
            }

            self.selectedFile = VideoFileInfo(
                url: url,
                fileName: url.lastPathComponent,
                fileSizeString: sizeString,
                resolution: resolutionStr,
                durationString: durationStr
            )
        }
    }

    public func startConversion() {
        guard let sourceURL = selectedFile?.url,
              let destinationURL = effectiveOutputURL else { return }

        isConverting = true
        errorMessage = nil
        completedURL = nil
        logs = []
        elapsedSeconds = 0

        startTimer()

        let options = ConversionOptions(
            crf: Int(crf),
            preset: preset,
            stripAudio: stripAudio,
            keyint: 60
        )

        let converter = self.converter

        Task.detached { [weak self] in
            do {
                let output = try converter.convert(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    options: options,
                    onPhaseChanged: { newPhase in
                        Task { @MainActor in
                            self?.phase = newPhase
                        }
                    },
                    onLog: { log in
                        Task { @MainActor in
                            self?.appendLog(log)
                        }
                    }
                )

                await MainActor.run {
                    guard let self = self else { return }
                    self.stopTimer()
                    self.isConverting = false
                    self.completedURL = output
                    self.phase = .completed(outputURL: output)
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.stopTimer()
                    self.isConverting = false
                    self.phase = .failed(error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                    self.appendLog("❌ ERROR: \(error.localizedDescription)")
                }
            }
        }
    }

    public func cancelConversion() {
        converter.cancel()
        stopTimer()
        isConverting = false
        phase = .cancelled
        appendLog("⚠️ Conversion cancelled by user.")
    }

    public func revealInFinder() {
        guard let url = completedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func resetAll() {
        selectedFile = nil
        customOutputDirectory = nil
        outputFileName = ""
        phase = .idle
        isConverting = false
        logs = []
        errorMessage = nil
        completedURL = nil
        elapsedSeconds = 0
    }

    private func appendLog(_ text: String) {
        logs.append(text)
        if logs.count > 500 {
            logs.removeFirst(100)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
