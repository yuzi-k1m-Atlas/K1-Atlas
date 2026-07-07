import SwiftUI
import AppKit

struct ContentView: View {

    @StateObject private var atlas = AtlasViewModel()

    @State private var selectedVoiceIDs = Set<UUID>()
    @State private var undoStack: [[K1Voice]] = []
    @State private var bankHeader: [UInt8] = [0xF0, 0x40, 0x00, 0x20, 0x00, 0x03, 0x00, 0x00]
    @State private var message = ""

    var body: some View {
        VStack(spacing: 14) {
            Text("K1 Atlas")
                .font(.largeTitle)
                .bold()

            Text("Modern Patch Librarian")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Open File") {
                    openFile()
                }

                Button("Open Folder") {
                    openFolder()
                }

                Button("Delete Selected") {
                    deleteSelected()
                }
                .disabled(selectedVoiceIDs.isEmpty)

                Button("Undo") {
                    undoDelete()
                }
                .disabled(undoStack.isEmpty)

                Button("Export Bank") {
                    exportBank()
                }
                .disabled(atlas.visibleVoices.count < 32)
            }

            Divider()

            Text(atlas.selectedSource)
                .font(.headline)

            Text(atlas.fileInfo)
                .foregroundStyle(.secondary)

            HStack {
                Button(atlas.duplicateMode ? "Show All" : "Show Duplicates") {
                    atlas.duplicateMode.toggle()
                    selectedVoiceIDs.removeAll()
                }

                Button(atlas.smartCleanMode ? "Smart Clean: ON" : "Smart Clean") {
                    atlas.smartCleanMode.toggle()
                    selectedVoiceIDs.removeAll()
                }

                Text(statusText)
                    .foregroundStyle(.secondary)
            }

            TextField("Search voices or source files", text: $atlas.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 460)

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List(atlas.visibleVoices, selection: $selectedVoiceIDs) { voice in
                HStack {
                    Text(voice.displayNumber)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)

                    Text(voice.name)
                        .frame(width: 140, alignment: .leading)

                    Text(voice.sourceFile)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if atlas.removedDuplicateIDs.contains(voice.id) {
                        Text("Removed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if atlas.duplicateFingerprints.contains(voice.fingerprint) {
                        Text("Kept")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(minHeight: 380)

            Spacer()
        }
        .padding(30)
        .frame(minWidth: 980, minHeight: 760)
    }

    var statusText: String {
        if atlas.duplicateMode && atlas.smartCleanMode {
            return "\(atlas.visibleVoices.count) removed duplicates shown"
        } else if atlas.duplicateMode {
            return "\(atlas.visibleVoices.count) duplicate-related voices shown"
        } else if atlas.smartCleanMode {
            return "\(atlas.visibleVoices.count) cleaned voices / \(atlas.duplicateCount) removed"
        } else {
            return "\(atlas.visibleVoices.count) shown"
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadFiles([url], sourceName: url.lastPathComponent)
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let folderURL = panel.url {
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: nil
                )
                .filter { $0.pathExtension.lowercased() == "syx" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

                loadFiles(files, sourceName: folderURL.lastPathComponent)

            } catch {
                atlas.selectedSource = folderURL.lastPathComponent
                atlas.fileInfo = "Error: \(error.localizedDescription)"
                atlas.voices.removeAll()
            }
        }
    }

    func loadFiles(_ urls: [URL], sourceName: String) {
        atlas.selectedSource = sourceName
        atlas.voices.removeAll()
        atlas.searchText = ""
        atlas.duplicateMode = false
        atlas.smartCleanMode = false
        selectedVoiceIDs.removeAll()
        undoStack.removeAll()
        message = ""

        var loadedVoices: [K1Voice] = []
        var bankCount = 0
        var singleCount = 0
        var unknownCount = 0

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let bytes = [UInt8](data)

                if bytes.count == 97 {
                    singleCount += 1
                    let name = readName(from: bytes, start: 8)

                    loadedVoices.append(
                        K1Voice(
                            sourceFile: url.lastPathComponent,
                            number: 1,
                            name: name,
                            rawData: Array(bytes[8..<96])
                        )
                    )

                } else if bytes.count == 2825 {
                    bankCount += 1
                    bankHeader = Array(bytes[0..<8])

                    for index in 0..<32 {
                        let start = 8 + (index * 88)
                        let end = start + 88

                        guard end <= bytes.count else { continue }

                        let voiceData = Array(bytes[start..<end])
                        let name = readName(from: bytes, start: start)

                        loadedVoices.append(
                            K1Voice(
                                sourceFile: url.lastPathComponent,
                                number: index + 1,
                                name: name,
                                rawData: voiceData
                            )
                        )
                    }

                } else {
                    unknownCount += 1
                }

            } catch {
                unknownCount += 1
            }
        }

        atlas.voices = loadedVoices
        atlas.fileInfo = "\(bankCount) banks / \(singleCount) singles / \(unknownCount) unknown / \(atlas.voices.count) voices / \(atlas.uniqueCount) unique / \(atlas.duplicateCount) duplicates"
    }

    func deleteSelected() {
        let selected = atlas.voices.filter { selectedVoiceIDs.contains($0.id) }

        guard !selected.isEmpty else { return }

        undoStack.append(selected)
        atlas.voices.removeAll { selectedVoiceIDs.contains($0.id) }
        selectedVoiceIDs.removeAll()

        message = "Deleted \(selected.count) voice(s)."
    }

    func undoDelete() {
        guard let lastDeleted = undoStack.popLast() else { return }

        atlas.voices.append(contentsOf: lastDeleted)
        atlas.voices.sort {
            if $0.sourceFile == $1.sourceFile {
                return $0.number < $1.number
            }
            return $0.sourceFile < $1.sourceFile
        }

        message = "Undo restored \(lastDeleted.count) voice(s)."
    }

    func exportBank() {
        let exportVoices = Array(atlas.visibleVoices.prefix(32))

        guard exportVoices.count == 32 else {
            message = "Export Bank needs 32 voices."
            return
        }

        var exportBytes: [UInt8] = bankHeader

        for voice in exportVoices {
            exportBytes.append(contentsOf: voice.rawData)
        }

        exportBytes.append(0xF7)

        saveSysEx(exportBytes, suggestedName: "K1_Atlas_Bank.syx")
    }

    func saveSysEx(_ bytes: [UInt8], suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = []

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try Data(bytes).write(to: url)
                message = "Exported: \(url.lastPathComponent) / \(bytes.count) bytes"
            } catch {
                message = "Export error: \(error.localizedDescription)"
            }
        }
    }

    func readName(from bytes: [UInt8], start: Int) -> String {
        guard start + 8 <= bytes.count else {
            return "(invalid)"
        }

        let nameBytes = bytes[start..<(start + 8)]

        let name = nameBytes.map { byte -> Character in
            if byte >= 32 && byte <= 126 {
                return Character(UnicodeScalar(byte))
            } else {
                return " "
            }
        }

        return String(name).trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    ContentView()
}
