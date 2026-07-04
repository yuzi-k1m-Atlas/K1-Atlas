import SwiftUI
import AppKit

struct K1Voice: Identifiable, Hashable {
    let id = UUID()
    let sourceFile: String
    let number: Int
    let name: String
    let rawData: [UInt8]

    var displayNumber: String {
        String(format: "%02d", number)
    }

    var fingerprint: String {
        rawData.map { String(format: "%02X", $0) }.joined()
    }
}

struct ContentView: View {
    @State private var selectedSource = "No library loaded"
    @State private var fileInfo = ""
    @State private var voices: [K1Voice] = []
    @State private var searchText = ""
    @State private var duplicateMode = false
    @State private var smartCleanMode = false

    var duplicateGroups: [String: [K1Voice]] {
        Dictionary(grouping: voices, by: { $0.fingerprint })
            .filter { $0.value.count > 1 }
    }

    var duplicateFingerprints: Set<String> {
        Set(duplicateGroups.keys)
    }

    var removedDuplicateIDs: Set<UUID> {
        var removed = Set<UUID>()

        for group in duplicateGroups.values {
            let sorted = group.sorted {
                if $0.sourceFile == $1.sourceFile {
                    return $0.number < $1.number
                }
                return $0.sourceFile < $1.sourceFile
            }

            for voice in sorted.dropFirst() {
                removed.insert(voice.id)
            }
        }

        return removed
    }

    var cleanedVoices: [K1Voice] {
        voices.filter { !removedDuplicateIDs.contains($0.id) }
    }

    var visibleVoices: [K1Voice] {
        var result: [K1Voice]

        if duplicateMode && smartCleanMode {
            // Smart Cleanで「消える側」だけ表示
            result = voices.filter { removedDuplicateIDs.contains($0.id) }
        } else if duplicateMode {
            // 重複グループ全部を表示
            result = voices.filter { duplicateFingerprints.contains($0.fingerprint) }
        } else if smartCleanMode {
            // 重複除去後のライブラリ
            result = cleanedVoices
        } else {
            result = voices
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceFile.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var uniqueCount: Int {
        Set(voices.map { $0.fingerprint }).count
    }

    var duplicateCount: Int {
        max(0, voices.count - uniqueCount)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("K1 Atlas")
                .font(.largeTitle)
                .bold()

            Text("Modern Patch Librarian")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Open File") {
                    openFile()
                }

                Button("Open Folder") {
                    openFolder()
                }
            }

            Divider()

            Text(selectedSource)
                .font(.headline)

            Text(fileInfo)
                .foregroundStyle(.secondary)

            HStack {
                Button(duplicateMode ? "Show All" : "Show Duplicates") {
                    duplicateMode.toggle()
                }

                Button(smartCleanMode ? "Smart Clean: ON" : "Smart Clean") {
                    smartCleanMode.toggle()
                }

                Text(statusText)
                    .foregroundStyle(.secondary)
            }

            TextField("Search voices or source files", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

            List(visibleVoices) { voice in
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

                    if removedDuplicateIDs.contains(voice.id) {
                        Text("Removed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if duplicateFingerprints.contains(voice.fingerprint) {
                        Text("Kept")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(minHeight: 360)

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 900, minHeight: 700)
    }

    var statusText: String {
        if duplicateMode && smartCleanMode {
            return "\(visibleVoices.count) removed duplicates shown"
        } else if duplicateMode {
            return "\(visibleVoices.count) duplicate-related voices shown"
        } else if smartCleanMode {
            return "\(visibleVoices.count) cleaned voices / \(duplicateCount) removed"
        } else {
            return "\(visibleVoices.count) shown"
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
                selectedSource = folderURL.lastPathComponent
                fileInfo = "Error: \(error.localizedDescription)"
                voices.removeAll()
            }
        }
    }

    func loadFiles(_ urls: [URL], sourceName: String) {
        selectedSource = sourceName
        voices.removeAll()
        searchText = ""
        duplicateMode = false
        smartCleanMode = false

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

        voices = loadedVoices

        fileInfo = "\(bankCount) banks / \(singleCount) singles / \(unknownCount) unknown / \(voices.count) voices / \(uniqueCount) unique / \(duplicateCount) duplicates"
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
