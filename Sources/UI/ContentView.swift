import SwiftUI
import AppKit

public struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    if let file = viewModel.selectedFile {
                        selectedFileInfoCard(file: file)
                        outputDestinationCard
                        settingsCard
                    } else {
                        dropZoneView
                    }

                    if viewModel.isConverting || !viewModel.logs.isEmpty {
                        statusAndProgressSection
                        logConsoleSection
                    }
                }
                .padding(20)
            }

            Divider()

            bottomActionBar
        }
        .frame(minWidth: 620, minHeight: 640)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Jem Wallpaper Converter")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Convert MP4 / MOV to macOS wallpaper-compatible QuickTime MOV")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if WallpaperConverter.findFFmpeg() != nil {
                Label("ffmpeg ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
            } else {
                Label("ffmpeg missing", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Drop Zone
    private var dropZoneView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(viewModel.isTargeted ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.08))
                    .frame(width: 84, height: 84)

                Image(systemName: viewModel.isTargeted ? "arrow.down.doc.fill" : "video.fill.badge.plus")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 6) {
                Text(viewModel.isTargeted ? "Drop Video to Load" : "Drag & Drop MP4 or MOV here")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Supports .mp4, .mov, .m4v videos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                viewModel.selectFileViaPanel()
            }) {
                Label("Browse Files...", systemImage: "folder")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    viewModel.isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isTargeted ? Color.accentColor.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
        )
        .onDrop(of: [.fileURL, .movie, .mpeg4Movie, .quickTimeMovie], isTargeted: $viewModel.isTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }

    // MARK: - File Info Card
    private func selectedFileInfoCard(file: VideoFileInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "film.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.fileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(file.url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 16) {
                        Label(file.fileSizeString, systemImage: "internaldrive")
                        if let res = file.resolution {
                            Label(res, systemImage: "aspectratio")
                        }
                        if let dur = file.durationString {
                            Label(dur, systemImage: "clock")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    viewModel.resetAll()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isConverting)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Output Destination Card
    private var outputDestinationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Output Settings")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Filename:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    TextField("Output Name", text: $viewModel.outputFileName)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .disabled(viewModel.isConverting)
                }

                HStack {
                    Text("Destination:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)

                    Text(viewModel.effectiveOutputURL?.deletingLastPathComponent().path ?? "")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                        .cornerRadius(6)

                    Button("Choose...") {
                        viewModel.selectOutputDirectory()
                    }
                    .disabled(viewModel.isConverting)

                    if viewModel.customOutputDirectory != nil {
                        Button("Reset") {
                            viewModel.resetOutputDirectory()
                        }
                        .disabled(viewModel.isConverting)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { !viewModel.stripAudio },
                        set: { viewModel.stripAudio = !$0 }
                    )) {
                        HStack(spacing: 4) {
                            Text("Preserve audio track")
                                .font(.caption)
                            Text("(removing audio is recommended for live wallpapers)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(viewModel.isConverting)

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Settings Card
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $viewModel.showAdvancedSettings) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Quality (CRF):")
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)

                        Slider(value: $viewModel.crf, in: 14...28, step: 1)
                            .disabled(viewModel.isConverting)

                        Text("\(Int(viewModel.crf))")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 30)
                    }

                    HStack {
                        Text("Speed Preset:")
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)

                        Picker("", selection: $viewModel.preset) {
                            ForEach(viewModel.presets, id: \.self) { p in
                                Text(p.capitalized).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.isConverting)

                        Spacer()
                    }


                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Encoder Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("CRF \(Int(viewModel.crf)) • \(viewModel.preset)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Status and Progress
    private var statusAndProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                switch viewModel.phase {
                case .idle:
                    Label("Ready", systemImage: "circle")
                        .foregroundColor(.secondary)
                case .encoding:
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Text("Encoding HEVC via libx265 (Elapsed: \(viewModel.elapsedSeconds)s)...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                case .patchingAtoms:
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Text("Injecting QuickTime Wallpaper Atoms (csgm, sgpd, tapt, cslg)...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                case .validating:
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Text("Validating wallpaper compatibility...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                case .completed:
                    Label("Conversion Complete!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                case .cancelled:
                    Label("Cancelled", systemImage: "xmark.circle")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                case .failed(let msg):
                    Label("Failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.headline)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isConverting {
                    Button("Cancel") {
                        viewModel.cancelConversion()
                    }
                    .controlSize(.small)
                } else if case .completed = viewModel.phase {
                    Button("Reveal in Finder") {
                        viewModel.revealInFinder()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if viewModel.isConverting {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Log Console
    private var logConsoleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation { viewModel.isLogExpanded.toggle() }
                }) {
                    Label(viewModel.isLogExpanded ? "Hide Logs" : "Show Logs", systemImage: viewModel.isLogExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.logs.count) lines")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if viewModel.isLogExpanded {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(log.contains("ERROR") ? .red : (log.contains("✓") ? .green : .white.opacity(0.85)))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 140)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(8)
                    .onChange(of: viewModel.logs.count) {
                        if let last = viewModel.logs.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack {
            if viewModel.selectedFile != nil {
                Button("Choose Another Video") {
                    viewModel.resetAll()
                }
                .disabled(viewModel.isConverting)
            }

            Spacer()

            if let _ = viewModel.selectedFile {
                if case .completed = viewModel.phase {
                    Button(action: {
                        viewModel.resetAll()
                    }) {
                        Label("Convert Another", systemImage: "arrow.clockwise")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        viewModel.startConversion()
                    }) {
                        Label("Convert to Wallpaper MOV", systemImage: "sparkles")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isConverting || WallpaperConverter.findFFmpeg() == nil)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
