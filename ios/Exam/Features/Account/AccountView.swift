import SwiftUI
import AuthenticationServices

/// Lets an anonymous learner save progress with Apple, Google or email,
/// and shows the linked account once upgraded.
struct AccountView: View {
    let copy: LocalizedCopy
    let onClose: () -> Void

    @ObservedObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = true
    @State private var busy = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ExamPalette.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(ExamPalette.surface)
                            .clipShape(Circle())
                    }
                }

                if auth.account.isSignedIn && !auth.account.isAnonymous {
                    linkedAccount
                } else {
                    signInOptions
                }

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(isError ? ExamPalette.coral : ExamPalette.mint)
                }
            }
            .padding(20)
        }
        .background(ExamPalette.background.ignoresSafeArea())
        .disabled(busy)
    }

    private var signInOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.text("account_title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ExamPalette.textPrimary)
            Text(copy.text("account_subtitle"))
                .font(.system(size: 15))
                .foregroundStyle(ExamPalette.textSecondary)

            SignInWithAppleButton(.continue) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                run { try await auth.completeApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                run { try await auth.continueWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Text("G").font(.system(size: 18, weight: .bold)).foregroundStyle(ExamPalette.primary)
                    Text(copy.text("account_continue_google"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ExamPalette.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(ExamPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ExamPalette.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack {
                Rectangle().fill(ExamPalette.border).frame(height: 1)
                Text(copy.text("account_or_email"))
                    .font(.system(size: 12))
                    .foregroundStyle(ExamPalette.textSecondary)
                Rectangle().fill(ExamPalette.border).frame(height: 1)
            }

            VStack(spacing: 10) {
                field(copy.text("account_email"), text: $email, secure: false)
                field(copy.text("account_password"), text: $password, secure: true)
            }

            ExamPrimaryButton(
                title: copy.text(createAccount ? "account_create" : "account_sign_in"),
                enabled: email.contains("@") && password.count >= 6
            ) {
                run {
                    try await auth.continueWithEmail(email: email, password: password, createAccount: createAccount)
                }
            }

            HStack {
                Button(copy.text(createAccount ? "account_have_account" : "account_need_account")) {
                    createAccount.toggle()
                    message = nil
                }
                Spacer()
                if !createAccount {
                    Button(copy.text("account_forgot_password")) {
                        run(success: copy.text("account_reset_sent")) {
                            try await auth.sendPasswordReset(email: email)
                        }
                    }
                    .disabled(!email.contains("@"))
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ExamPalette.primary)
        }
    }

    private var linkedAccount: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.text("account_saved_title"))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ExamPalette.textPrimary)
            Text(auth.account.email ?? copy.text("account_saved_subtitle"))
                .font(.system(size: 15))
                .foregroundStyle(ExamPalette.textSecondary)

            ExamPrimaryButton(title: copy.text("account_sign_out")) {
                run { try await auth.signOut() }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(title, text: text).textContentType(.password)
            } else {
                TextField(title, text: text)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(ExamPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ExamPalette.border, lineWidth: 1)
        )
    }

    private func run(success: String? = nil, _ work: @escaping () async throws -> Void) {
        busy = true
        message = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await work()
                isError = false
                message = success
                if success == nil {
                    AppServices.shared.analytics.event("account_linked")
                }
            } catch AuthServiceError.cancelled {
                // User dismissed the provider sheet; nothing to report.
            } catch {
                isError = true
                message = error.localizedDescription
            }
        }
    }
}
