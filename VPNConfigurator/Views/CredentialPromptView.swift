import SwiftUI

struct CredentialPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    let request: AuthenticationRequest

    @State private var password = ""
    @State private var oneTimePassword = ""
    @State private var rememberPassword = true
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "person.badge.key.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(.blue.opacity(0.15)), in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Authenticate")
                        .font(.title2.bold())
                    Text(request.profileName)
                        .foregroundStyle(.secondary)
                }
            }

            // Both inputs are masked, so each one states what it is. Without a
            // heading a lone OTP box reads as an ordinary password prompt.
            if request.usesStoredPassword {
                Label("Using the password saved in your Keychain.", systemImage: "key.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Password")
                        .font(.subheadline.weight(.medium))
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Remember in Keychain", isOn: $rememberPassword)
                }
            }

            if request.method == .passwordAndOTP {
                VStack(alignment: .leading, spacing: 7) {
                    Text("One-time password")
                        .font(.subheadline.weight(.medium))
                    SecureField("Code from your authenticator", text: $oneTimePassword)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for this connection only and never saved. This is not your account password.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    controller.cancelAuthentication()
                    dismiss()
                }
                Spacer()
                Button("Connect") { submit() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 460)
        .interactiveDismissDisabled()
    }

    private func submit() {
        do {
            try controller.submitAuthentication(
                password: password,
                oneTimePassword: oneTimePassword,
                rememberPassword: rememberPassword,
                useStoredPassword: request.usesStoredPassword
            )
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
