import Foundation
import FirebaseCore
@preconcurrency import FirebaseFunctions

enum AIGatewayError: LocalizedError {
    case firebaseUnavailable
    case invalidResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            "Firebase is not configured."
        case .invalidResponse:
            "Invalid backend response."
        case .message(let value):
            value
        }
    }
}

struct MediaJob: Hashable {
    let requestId: String
    let creditCost: Int
}

struct MediaJobStatus {
    let status: String
    let data: Any?
}

@MainActor
final class AIGatewayClient {
    private func call(_ name: String, payload: [String: Any]) async throws -> [String: Any] {
        guard FirebaseApp.app() != nil else {
            throw AIGatewayError.firebaseUnavailable
        }

        do {
            let result: HTTPSCallableResult = try await withCheckedThrowingContinuation { continuation in
                Functions.functions().httpsCallable(name).call(payload) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: AIGatewayError.invalidResponse)
                    }
                }
            }

            guard let data = result.data as? [String: Any] else {
                throw AIGatewayError.invalidResponse
            }
            return data
        } catch let error as AIGatewayError {
            throw error
        } catch {
            throw AIGatewayError.message(error.localizedDescription)
        }
    }

    func askTutor(setup: StudySetup, message: String) async throws -> String {
        let data = try await call("aiTutor", payload: [
            "examId": setup.exam.id,
            "contentPackId": setup.exam.syllabusPackId,
            "language": setup.languageCode,
            "message": message
        ])
        return data["text"] as? String ?? ""
    }

    func solveQuestion(
        setup: StudySetup,
        extractedText: String?,
        imageDataURL: String?
    ) async throws -> String {
        var payload: [String: Any] = [
            "examId": setup.exam.id,
            "contentPackId": setup.exam.syllabusPackId,
            "language": setup.languageCode
        ]
        if let extractedText { payload["extractedText"] = extractedText }
        if let imageDataURL { payload["imageDataUrl"] = imageDataURL }

        let data = try await call("solveQuestion", payload: payload)
        return data["text"] as? String ?? ""
    }

    func generatePractice(
        setup: StudySetup,
        topic: String,
        count: Int = 5
    ) async throws -> [[String: Any]] {
        let data = try await call("generatePractice", payload: [
            "examId": setup.exam.id,
            "contentPackId": setup.exam.syllabusPackId,
            "language": setup.languageCode,
            "topic": topic,
            "count": count
        ])
        return data["questions"] as? [[String: Any]] ?? []
    }

    func indexMaterial(
        materialId: String,
        title: String,
        mimeType: String,
        storagePath: String?,
        extractedText: String?
    ) async throws -> [String: Any] {
        var payload: [String: Any] = [
            "materialId": materialId,
            "title": title,
            "mimeType": mimeType
        ]
        if let storagePath { payload["storagePath"] = storagePath }
        if let extractedText { payload["extractedText"] = extractedText }
        return try await call("indexMaterial", payload: payload)
    }

    func askMaterial(
        materialId: String,
        question: String,
        language: String
    ) async throws -> String {
        let data = try await call("askMaterial", payload: [
            "materialId": materialId,
            "question": question,
            "language": language
        ])
        return data["text"] as? String ?? ""
    }

    func generateMaterialPractice(
        materialId: String,
        language: String,
        count: Int = 5
    ) async throws -> [[String: Any]] {
        let data = try await call("generateMaterialPractice", payload: [
            "materialId": materialId,
            "language": language,
            "count": count
        ])
        return data["questions"] as? [[String: Any]] ?? []
    }

    func generateMedia(kind: String, prompt: String) async throws -> MediaJob {
        let data = try await call("mediaGenerate", payload: [
            "kind": kind,
            "prompt": prompt
        ])
        guard let id = data["requestId"] as? String else {
            throw AIGatewayError.invalidResponse
        }
        return MediaJob(
            requestId: id,
            creditCost: (data["creditCost"] as? NSNumber)?.intValue ?? 0
        )
    }

    func mediaStatus(requestId: String) async throws -> MediaJobStatus {
        let data = try await call("mediaStatus", payload: [
            "requestId": requestId
        ])
        return MediaJobStatus(
            status: data["status"] as? String ?? "unknown",
            data: data["data"]
        )
    }

    func transcribeAudio(storagePath: String) async throws -> String {
        let data = try await call("transcribeAudio", payload: [
            "storagePath": storagePath
        ])
        return data["text"] as? String ?? ""
    }

    func synthesizeSpeech(text: String) async throws -> String {
        let data = try await call("synthesizeSpeech", payload: ["text": text])
        return data["storagePath"] as? String ?? ""
    }
}
