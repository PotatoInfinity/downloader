import SwiftUI
import DownloaderCore

struct ContentView: View {
    @EnvironmentObject private var manager: DownloadManager
    @FocusState private var inputFocused: Bool

    private var detection: LinkDetection {
        LinkDetector.detect(in: manager.input)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inputField
            metaRow
                .padding(.top, 8)
            formatRow
                .padding(.top, 18)
            downloadButton
                .padding(.top, 14)

            if !manager.items.isEmpty {
                downloadsSection
                    .padding(.top, 18)
            }

            Spacer(minLength: 12)
            footer
        }
        .padding(20)
        .frame(width: 540, height: 560, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            inputFocused = true
        }
    }

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $manager.input)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .disabled(manager.isDownloading)
                .focused($inputFocused)
                .accessibilityIdentifier("linksInput")

            if manager.input.isEmpty {
                Text("Paste links.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 11)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(linkSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if !manager.input.isEmpty && !manager.isDownloading {
                Button("Clear") {
                    manager.clearInput()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("clearButton")
            }
        }
    }

    private var linkSummary: String {
        let count = detection.supported.count
        var text: String
        if count == 0 {
            text = detection.unsupportedCount == 0 ? "No links." : "No supported links."
        } else {
            text = count == 1 ? "1 link." : "\(count) links."
        }
        if detection.unsupportedCount > 0 && count > 0 {
            text += " \(detection.unsupportedCount) ignored."
        }
        return text
    }

    private var formatRow: some View {
        HStack(spacing: 10) {
            Text("Format")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Picker("", selection: $manager.format) {
                ForEach(MediaFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 78)
            .disabled(manager.isDownloading)
            .accessibilityIdentifier("formatMenu")

            Spacer()
        }
    }

    private var downloadButton: some View {
        Button {
            manager.start()
        } label: {
            Text(manager.isDownloading ? "Downloading" : "Download")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SolidButtonStyle())
        .disabled(manager.links.isEmpty || manager.isDownloading || !manager.isReady)
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityIdentifier("downloadButton")
    }

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Downloads")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                if manager.isDownloading {
                    Button("Cancel") {
                        manager.cancel()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Text("\(manager.finishedCount) of \(manager.items.count)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                        DownloadRow(item: item)
                        if index != manager.items.count - 1 {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .frame(maxHeight: 174)
            .scrollIndicators(.hidden)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(manager.statusText)
                .font(.system(size: 10.5))
                .foregroundStyle(manager.isReady ? Color.secondary : Color(nsColor: .systemRed))
                .lineLimit(1)

            Spacer()

            if manager.canReveal {
                Button("Show in Finder") {
                    manager.revealOutputFolder()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("showInFinderButton")
            }
        }
    }
}

private struct DownloadRow: View {
    let item: DownloadItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.symbolName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(item.isFailed ? Color(nsColor: .systemRed) : Color.secondary)
                .frame(width: 12, height: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let message = item.failureMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let message = item.retryMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                } else if let progress = item.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                }
            }

            Spacer(minLength: 4)

            Text(item.stateLabel)
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 56, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

private struct SolidButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .frame(height: 38)
            .background(
                Color.primary.opacity(
                    configuration.isPressed ? 0.75 : (isEnabled ? 1 : 0.25)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
