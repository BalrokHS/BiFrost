import Foundation

final class VPNSession: @unchecked Sendable {
    let profileID: String
    let clientName: String
    let process: Process
    let temporaryURLs: [URL]
    var resolverKey: String?
    let dnsServers: [String]
    let dnsDomains: [String]
    let connectedMarkers: [String]
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    var state = HelperSessionState.connecting
    var interfaceName = ""
    var log = ""
    var stopRequested = false
    var didProcessConnectedMarker = false
    var didDetectAuthenticationFailure = false
    var didFinish = false

    init(
        profileID: String,
        clientName: String,
        process: Process,
        temporaryURLs: [URL],
        dnsServers: [String],
        dnsDomains: [String],
        connectedMarkers: [String]
    ) {
        self.profileID = profileID
        self.clientName = clientName
        self.process = process
        self.temporaryURLs = temporaryURLs
        self.dnsServers = dnsServers
        self.dnsDomains = dnsDomains
        self.connectedMarkers = connectedMarkers
    }
}
