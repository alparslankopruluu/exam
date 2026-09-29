import SwiftUI
import AVKit

struct VoiceTutorView: View {
    let setup: StudySetup
    let onClose: () -> Void

    @State private var service = VoiceTutorService()
    @State private var recording = false
    @State private var processing = false
    @State private var result: VoiceTutorResult?
    @State private var error: String?
    @State private var player: AVPlayer?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ExamPalette.textPrimary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(setup.exam.shortName) · PREMIUM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ExamPalette.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ExamPalette.softPurple)
                    .clipShape(Capsule())
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(copy.text("voice_tutor"))
                        .font(.system(size: 30, weight: .bold))
                        .padding(.top, 24)

                    Text(copy.text("voice_intro", variables: ["exam": setup.exam.shortName]))
                        .font(.system(size: 14))
                        .foregroundStyle(ExamPalette.textSecondary)
                        .lineSpacing(3)
                        .padding(.top, 6)

                    VStack(spacing: 12) {
                        if processing {
                            ProgressView()
                                .tint(ExamPalette.purple)
                            Text(copy.text("voice_thinking"))
                                .font(.system(size: 14))
                                .foregroundStyle(ExamPalette.textSecondary)
                        } else if recording {
                            Image(systemName: "waveform")
                                .font(.system(size: 54, weight: .semibold))
                                .foregroundStyle(ExamPalette.coral)
                            Text(copy.text("voice_listening"))
                                .font(.system(size: 20, weight: .bold))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 50, weight: .semibold))
                                .foregroundStyle(ExamPalette.purple)
                            Text(copy.text("voice_tap_to_ask"))
                                .font(.system(size: 19, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .background(ExamPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.top, 28)

                    if let error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(ExamPalette.coral)
                            .padding(.top, 12)
                    }

                    if let result {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ExamPalette.textSecondary)
                            Text(result.transcript)
                                .font(.system(size: 13))
                                .lineSpacing(3)

                            Text(copy.text("tutor_label"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ExamPalette.purple)
                                .padding(.top, 4)
                            Text(result.answer)
                                .font(.system(size: 13))
                                .lineSpacing(3)

                            if let url = result.audioURL {
                                Button {
                                    let newPlayer = AVPlayer(url: url)
                                    player = newPlayer
                                    newPlayer.play()
                                } label: {
                                    Label("Play spoken answer", systemImage: "speaker.wave.2.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(ExamPalette.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(ExamPalette.softBlue)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .examCard(radius: 20)
                        .padding(.top, 18)
                    }
                }
            }

            Button {
                if recording {
                    stopAndAsk()
                } else {
                    start()
                }
            } label: {
                Label(
                    recording ? "Stop & ask" : "Start speaking",
                    systemImage: recording ? "stop.fill" : "mic.fill"
                )
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(recording ? ExamPalette.coral : ExamPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(processing)
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(ExamPalette.background.ignoresSafeArea())
        .onDisappear {
            service.cancel()
            player?.pause()
        }
    }

    private func start() {
        error = nil
        result = nil

        Task { @MainActor in
            guard await service.requestPermission() else {
                error = "Microphone permission is required for Voice Tutor."
                return
            }

            do {
                try service.startRecording()
                recording = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func stopAndAsk() {
        recording = false
        processing = true
        error = nil

        Task { @MainActor in
            do {
                result = try await service.stopAndProcess(setup: setup)
            } catch {
                self.error = error.localizedDescription
            }
            processing = false
        }
    }
}
