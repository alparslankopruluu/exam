import Foundation

enum FlashcardRating {
    case again
    case hard
    case good
    case easy
}

struct FlashcardScheduler {
    private let defaults = UserDefaults.standard

    func isDue(cardId: String, now: Date = .now) -> Bool {
        guard let due = defaults.object(forKey: "flashcard.\(cardId)") as? Date else {
            return true
        }
        return due <= now
    }

    func review(cardId: String, rating: FlashcardRating) {
        let hours: Int
        switch rating {
        case .again: hours = 1
        case .hard: hours = 12
        case .good: hours = 72
        case .easy: hours = 24 * 7
        }
        let due = Calendar.current.date(byAdding: .hour, value: hours, to: .now) ?? .now
        defaults.set(due, forKey: "flashcard.\(cardId)")
    }
}
