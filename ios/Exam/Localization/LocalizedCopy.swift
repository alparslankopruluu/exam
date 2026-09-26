import Foundation

struct LocalizedCopy {
    private let values: [String: String]
    private let fallback: [String: String]

    func text(_ key: String, variables: [String: String] = [:]) -> String {
        var value = values[key] ?? fallback[key] ?? key
        for (name, replacement) in variables {
            value = value.replacingOccurrences(of: "{\(name)}", with: replacement)
        }
        return value
    }

    static func load(languageCode: String, bundle: Bundle = .main) -> LocalizedCopy {
        func read(_ code: String) -> [String: String] {
            let urls = [
                bundle.url(forResource: code, withExtension: "json", subdirectory: "locales"),
                bundle.url(forResource: code, withExtension: "json")
            ].compactMap { $0 }

            guard let url = urls.first,
                  let data = try? Data(contentsOf: url),
                  let dictionary = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dictionary
        }

        let fallback = read("en")
        let normalized = languageCode.split(separator: "-").first.map(String.init)?.lowercased() ?? "en"
        let localized = normalized == "en" ? fallback : read(normalized)
        return LocalizedCopy(values: localized, fallback: fallback)
    }
}
