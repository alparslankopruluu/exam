import Foundation

/// Carries a route from a tapped notification to the visible screen.
/// Routes: "today", "review", "paywall".
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var pending: String?

    private init() {}

    func consume() -> String? {
        defer { pending = nil }
        return pending
    }
}
