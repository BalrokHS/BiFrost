import Foundation

struct AuthenticationRequest: Identifiable, Sendable {
    let profileID: VPNProfile.ID
    let profileName: String
    let method: AuthenticationMethod
    /// The password saved in the Keychain will be used, so the dialog collects
    /// only the one-time password. The controller decides this; there is no
    /// toggle, because being asked to choose is not a decision the user has the
    /// information to make at connect time.
    let usesStoredPassword: Bool
    /// The dialog asks for a code together with the password. Used by clients
    /// that cannot ask for it later; OpenFortiVPN asks once the server does.
    var collectsCode = false
    /// The server has asked for a code mid-connection, so the dialog is a
    /// code-only prompt with a deadline.
    var serverRequestedCode = false
    var deadline: Date?
    /// The previous code was not accepted.
    var isRetry = false
    var errorMessage: String?

    var id: VPNProfile.ID { profileID }
}

struct VPNCredentials: Sendable {
    var password: String?
    var oneTimePassword: String?
}
