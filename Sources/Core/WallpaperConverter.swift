import Foundation

public struct ConversionOptions: Sendable {
    public var crf: Int
    public var preset: String
    public var stripAudio: Bool
    public var keyint: Int

    public init(
        crf: Int = 18,
        preset: String = "medium",
        stripAudio: Bool = true,
        keyint: Int = 60
    ) {
        self.crf = crf
        self.preset = preset
        self.stripAudio = stripAudio
        self.keyint = keyint
    }
}

public enum ConversionPhase: Sendable, Equatable {
    case idle
    case encoding
    case patchingAtoms
    case validating
    case completed(outputURL: URL)
    case cancelled
    case failed(String)
}

public enum ConverterError: LocalizedError {
    case ffmpegNotFound
    case inputNotFound(URL)
    case encodeFailed(String)
    case patchFailed(String)
    case validationFailed([String])
    case cancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "ffmpeg was not found. Install it with Homebrew (`brew install ffmpeg`) or ensure it is accessible in PATH."
        case .inputNotFound(let url):
            return "Input file does not exist or cannot be read: \(url.path)"
        case .encodeFailed(let details):
            return "ffmpeg encoding failed. \(details.isEmpty ? "Check file format and libx265 support." : details)"
        case .patchFailed(let reason):
            return "Failed to patch QuickTime atoms: \(reason)"
        case .validationFailed(let missing):
            return "Wallpaper compatibility check failed. Missing atoms: \(missing.joined(separator: ", "))"
        case .cancelled:
            return "Conversion was cancelled."
        case .unknown(let msg):
            return msg
        }
    }
}

public final class WallpaperConverter: @unchecked Sendable {
    private let fm = FileManager.default
    private var currentProcess: Process?
    private let processLock = NSLock()
    private var isCancelled = false

    public init() {}

    public func cancel() {
        processLock.withLock {
            isCancelled = true
            currentProcess?.terminate()
        }
    }

    public static func findFFmpeg() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        let fm = FileManager.default
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/ffmpeg"
                if fm.isExecutableFile(atPath: candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }

        return nil
    }

    public static func defaultOutputURL(for inputURL: URL, in directory: URL? = nil) -> URL {
        let targetDir = directory ?? inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let sanitized = safeFileName(for: baseName)
        return targetDir.appendingPathComponent("\(sanitized)-wallpaper.mov")
    }

    public static func safeFileName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "wallpaper" : trimmed
        let invalid = CharacterSet(charactersIn: "/:\\").union(.controlCharacters).union(.newlines)
        let sanitized = fallback
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return sanitized.isEmpty ? "wallpaper" : sanitized
    }

    public func convert(
        sourceURL: URL,
        destinationURL: URL,
        options: ConversionOptions = ConversionOptions(),
        onPhaseChanged: @escaping @Sendable (ConversionPhase) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) throws -> URL {
        processLock.withLock {
            isCancelled = false
        }

        guard fm.fileExists(atPath: sourceURL.path) else {
            throw ConverterError.inputNotFound(sourceURL)
        }

        guard let ffmpegURL = Self.findFFmpeg() else {
            throw ConverterError.ffmpegNotFound
        }

        onPhaseChanged(.encoding)
        onLog("▶ Starting conversion for: \(sourceURL.lastPathComponent)")
        onLog("Using ffmpeg at: \(ffmpegURL.path)")
        onLog("Encoding settings: CRF \(options.crf), Preset \(options.preset), Keyint \(options.keyint), StripAudio: \(options.stripAudio)")

        let sessionID = UUID().uuidString
        let tempDir = fm.temporaryDirectory.appendingPathComponent("JemConverter_\(sessionID)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let x265URL = tempDir.appendingPathComponent("encoded.mov")
        let patchedURL = tempDir.appendingPathComponent("patched.mov")
        let fixedURL = tempDir.appendingPathComponent("fixed.mov")

        // 1. ffmpeg encode
        var ffmpegArgs = [
            "-nostdin",
            "-y",
            "-i", sourceURL.path,
            "-c:v", "libx265",
            "-pix_fmt", "yuv420p10le",
            "-crf", "\(options.crf)",
            "-preset", options.preset,
            "-tag:v", "hvc1",
            "-x265-params", "keyint=\(options.keyint):min-keyint=\(options.keyint):scenecut=0:bframes=4:b-adapt=2:b-pyramid=1:temporal-layers=3",
            "-color_range", "tv",
            "-color_primaries", "bt709",
            "-color_trc", "bt709",
            "-colorspace", "bt709",
            "-metadata:s:v", "handler_name=Core Media Video",
            "-metadata:s:v", "encoder=HEVC"
        ]

        if options.stripAudio {
            ffmpegArgs.append("-an")
        } else {
            ffmpegArgs += ["-c:a", "aac"]
        }

        ffmpegArgs.append(x265URL.path)

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = ffmpegArgs
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardError = pipe

        let readHandle = pipe.fileHandleForReading
        readHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: .newlines) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                onLog(line)
            }
        }

        processLock.withLock {
            currentProcess = process
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            readHandle.readabilityHandler = nil
            throw ConverterError.encodeFailed(error.localizedDescription)
        }

        readHandle.readabilityHandler = nil

        let cancelled = processLock.withLock { () -> Bool in
            let c = isCancelled
            currentProcess = nil
            return c
        }

        if cancelled {
            onPhaseChanged(.cancelled)
            throw ConverterError.cancelled
        }

        guard process.terminationStatus == 0 else {
            let status = process.terminationStatus
            throw ConverterError.encodeFailed("Process exited with code \(status)")
        }

        onLog("✓ ffmpeg x265 encoding complete.")

        // 2. Patch QuickTime atoms
        onPhaseChanged(.patchingAtoms)
        onLog("▶ Patching QuickTime container atoms (csgm, sgpd, tapt, cslg)...")

        do {
            let patcher = try AtomPatcher(fileURL: x265URL)
            try WallpaperInjector.patch(patcher: patcher)
            try patcher.save(outputURL: patchedURL)
            onLog("✓ Atoms injected successfully.")
        } catch {
            throw ConverterError.patchFailed(error.localizedDescription)
        }

        // 3. Remove FFMP vendor ID
        onLog("▶ Cleaning encoder vendor tags...")
        var data = try Data(contentsOf: patchedURL)
        var countReplaced = 0
        while let vendorRange = data.range(of: Data("FFMP".utf8)) {
            data.replaceSubrange(vendorRange, with: [0, 0, 0, 0])
            countReplaced += 1
        }
        if countReplaced > 0 {
            onLog("✓ Removed \(countReplaced) FFMP vendor tags.")
        }
        try data.write(to: fixedURL)

        // 4. Validate required atoms
        onPhaseChanged(.validating)
        onLog("▶ Validating wallpaper atom compatibility...")
        let requiredAtoms = ["csgm", "sgpd", "tapt", "cslg"]
        let missing = requiredAtoms.filter { atom in
            data.range(of: Data(atom.utf8)) == nil
        }

        for atom in requiredAtoms {
            let present = !missing.contains(atom)
            onLog("  Atom [\(atom)]: \(present ? "PRESENT" : "MISSING")")
        }

        guard missing.isEmpty else {
            throw ConverterError.validationFailed(missing)
        }
        onLog("✓ Wallpaper compatibility validation passed.")

        // 5. Copy to destination
        let destFolder = destinationURL.deletingLastPathComponent()
        try? fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
        try? fm.removeItem(at: destinationURL)
        try fm.copyItem(at: fixedURL, to: destinationURL)

        onLog("★ Successfully saved wallpaper to: \(destinationURL.path)")
        onPhaseChanged(.completed(outputURL: destinationURL))
        return destinationURL
    }
}
