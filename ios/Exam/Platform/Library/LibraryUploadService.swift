import Foundation
import UniformTypeIdentifiers
import FirebaseCore
import FirebaseAuth
import FirebaseStorage

struct UploadedMaterial: Hashable {
    let id: String
    let title: String
    let mimeType: String
    let storagePath: String
    let summary: String?
}

@MainActor
final class LibraryUploadService {
    private let ai = AIGatewayClient()

    func uploadAndIndex(url: URL) async throws -> UploadedMaterial {
        guard FirebaseApp.app() != nil else {
            throw AIGatewayError.firebaseUnavailable
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw AIGatewayError.message("User session is not ready.")
        }

        let materialId = UUID().uuidString.lowercased()
        let title = url.lastPathComponent.isEmpty ? "Study material" : url.lastPathComponent
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        let safeName = title
            .replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
            .prefix(120)
        let storagePath = "users/\(uid)/materials/\(materialId)/\(safeName)"

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let metadata = StorageMetadata()
        metadata.contentType = mimeType

        let reference = Storage.storage().reference(withPath: storagePath)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putFile(from: url, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let indexed = try await ai.indexMaterial(
            materialId: materialId,
            title: title,
            mimeType: mimeType,
            storagePath: storagePath,
            extractedText: nil
        )

        return UploadedMaterial(
            id: materialId,
            title: title,
            mimeType: mimeType,
            storagePath: storagePath,
            summary: indexed["summary"] as? String
        )
    }
}
