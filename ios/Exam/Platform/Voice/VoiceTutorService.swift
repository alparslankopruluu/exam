@preconcurrency import AVFoundation
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseStorage

struct VoiceTutorResult: Hashable {
    let transcript: String
    let answer: String
    let audioURL: URL?
}

@MainActor
final class VoiceTutorService {
    private let gateway = AIGatewayClient()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        guard recorder == nil else {
            throw AIGatewayError.message("Already recording.")
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.prepareToRecord()
        guard audioRecorder.record() else {
            throw AIGatewayError.message("Could not start recording.")
        }

        recordingURL = url
        recorder = audioRecorder
    }

    func stopAndProcess(setup: StudySetup) async throws -> VoiceTutorResult {
        guard let recorder, let recordingURL else {
            throw AIGatewayError.message("No active recording.")
        }

        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil

        defer {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        guard FirebaseApp.app() != nil,
              let uid = Auth.auth().currentUser?.uid else {
            throw AIGatewayError.firebaseUnavailable
        }

        let storagePath = "users/\(uid)/voice/\(UUID().uuidString).m4a"
        let reference = Storage.storage().reference(withPath: storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mp4"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putFile(from: recordingURL, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let transcript = try await gateway.transcribeAudio(storagePath: storagePath)
        let answer = try await gateway.askTutor(setup: setup, message: transcript)

        var audioURL: URL?
        do {
            let generatedPath = try await gateway.synthesizeSpeech(text: answer)
            let generatedRef = Storage.storage().reference(withPath: generatedPath)
            audioURL = try await withCheckedThrowingContinuation { continuation in
                generatedRef.downloadURL { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: AIGatewayError.invalidResponse)
                    }
                }
            }
        } catch {
            audioURL = nil
        }

        return VoiceTutorResult(
            transcript: transcript,
            answer: answer,
            audioURL: audioURL
        )
    }

    func cancel() {
        recorder?.stop()
        recorder = nil

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }
}
