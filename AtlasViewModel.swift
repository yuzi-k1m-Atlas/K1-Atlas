import Foundation
import SwiftUI

final class AtlasViewModel: ObservableObject {

    // MARK: - UI State

    @Published var selectedSource = "No library loaded"
    @Published var fileInfo = ""
    @Published var voices: [K1Voice] = []
    @Published var searchText = ""
    @Published var duplicateMode = false
    @Published var smartCleanMode = false
    @Published var project = AtlasProject()
    var duplicateGroups: [String: [K1Voice]] {
        Dictionary(grouping: voices, by: { $0.fingerprint })
            .filter { $0.value.count > 1 }
    }

    var duplicateFingerprints: Set<String> {
        Set(duplicateGroups.keys)
    }

    var uniqueCount: Int {
        Set(voices.map { $0.fingerprint }).count
    }

    var duplicateCount: Int {
        max(0, voices.count - uniqueCount)
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
        voices.filter {
            !removedDuplicateIDs.contains($0.id)
        }
    }

    var visibleVoices: [K1Voice] {
        var result: [K1Voice]

        if duplicateMode && smartCleanMode {
            result = voices.filter {
                removedDuplicateIDs.contains($0.id)
            }
        } else if duplicateMode {
            result = voices.filter {
                duplicateFingerprints.contains($0.fingerprint)
            }
        } else if smartCleanMode {
            result = cleanedVoices
        } else {
            result = voices
        }

        if searchText.isEmpty {
            return result
        }

        return result.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceFile.localizedCaseInsensitiveContains(searchText)
        }
    }
}
