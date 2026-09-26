import UIKit
import Vision

enum QuestionScannerError: Error {
    case invalidImage
}

final class QuestionScanner {
    func recognize(imageData: Data, languageCode: String) throws -> String {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw QuestionScannerError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages(for: languageCode)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recognitionLanguages(for code: String) -> [String] {
        switch code.lowercased().split(separator: "-").first.map(String.init) ?? "en" {
        case "tr": ["tr-TR", "en-US"]
        case "de": ["de-DE", "en-US"]
        case "es": ["es-ES", "en-US"]
        case "fr": ["fr-FR", "en-US"]
        case "pt": ["pt-BR", "en-US"]
        case "ko": ["ko-KR", "en-US"]
        case "ja": ["ja-JP", "en-US"]
        case "zh": ["zh-Hans", "zh-Hant", "en-US"]
        case "hi": ["hi-IN", "en-US"]
        default: ["en-US"]
        }
    }
}
