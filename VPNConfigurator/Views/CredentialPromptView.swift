import SwiftUI

struct CredentialPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    let request: AuthenticationRequest

    @State private var password = ""
    @State private var oneTimePassword = ""
    @State private var rememberPassword = true
    @State private var validationMessage: String?

    private enum Field { case password, otp }
    @FocusState private var focused: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            // Both inputs are masked, so each one states what it is. Without a
            // heading a lone OTP box reads as an ordinary password prompt.
            if request.usesStoredPassword {
                Label("Using the password saved in your Keychain.", systemImage: "key.fill")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mattePanel(radius: Theme.Radius.control)
            } else {
                field(
                    title: "Password",
                    prompt: "Password",
                    text: $password,
                    field: .password
                ) {
                    Toggle("Remember in Keychain", isOn: $rememberPassword)
                        .toggleStyle(.checkbox)
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.top, 2)
                }
            }

            if request.method == .passwordAndOTP {
                field(
                    title: "One-time password",
                    prompt: "Code from your authenticator",
                    text: $oneTimePassword,
                    field: .otp
                ) {
                    Text("Used for this connection only and never saved. This is not your account password.")
                        .font(.caption11)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption12)
                    .foregroundStyle(ConnectionState.failed.tone)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mattePanel(radius: Theme.Radius.control, fill: ConnectionState.failed.tone.opacity(0.10))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") {
                    controller.cancelAuthentication()
                    dismiss()
                }
                .buttonStyle(.quiet)
                .keyboardShortcut(.cancelAction)

                Button("Connect") { submit() }
                    .buttonStyle(.accent(Theme.Palette.brand))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 460)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .animation(Theme.Motion.state, value: validationMessage)
        .onAppear {
            focused = request.usesStoredPassword ? .otp : .password
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            IconBadge(
                symbol: "person.badge.key.fill",
                tint: Theme.Palette.brand,
                highlight: Theme.Palette.brandBright,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Authenticate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(request.profileName)
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func field<Accessory: View>(
        title: String,
        prompt: String,
        text: Binding<String>,
        field: Field,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(title, tone: Theme.Palette.textSecondary)

            SecureField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .focused($focused, equals: field)
                .fieldChrome(focused: focused == field)

            accessory()
        }
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
