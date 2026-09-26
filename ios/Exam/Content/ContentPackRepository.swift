import Foundation

struct ContentUnit: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let durationMinutes: Int?
    let questionCount: Int?
}

struct ExamContentPack: Hashable {
    let id: String
    let displayName: String
    let units: [ContentUnit]
}

private struct RawExamContentPack: Decodable {
    struct RawUnit: Decodable {
        let id: String
        let title: String
        let durationMinutes: Int?
        let questionCount: Int?
    }

    let id: String
    let displayName: String?
    let sections: [RawUnit]?
    let sessions: [RawUnit]?
}

enum ContentPackRepository {
    static func load(packId: String, bundle: Bundle = .main) -> ExamContentPack? {
        let candidateURLs = [
            bundle.url(forResource: packId, withExtension: "json", subdirectory: "packs"),
            bundle.url(forResource: packId, withExtension: "json")
        ].compactMap { $0 }

        guard let url = candidateURLs.first,
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(RawExamContentPack.self, from: data) else {
            return nil
        }

        let source = raw.sections ?? raw.sessions ?? []
        return ExamContentPack(
            id: raw.id,
            displayName: raw.displayName ?? packId,
            units: source.map {
                ContentUnit(
                    id: $0.id,
                    title: $0.title,
                    durationMinutes: $0.durationMinutes,
                    questionCount: $0.questionCount
                )
            }
        )
    }
}
