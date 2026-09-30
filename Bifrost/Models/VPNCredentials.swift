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

    var id: VPNProfile.ID { profileID }
}

struct VPNCredentials: Sendable {
    var password: String?
    var oneTimePassword: String?
}
