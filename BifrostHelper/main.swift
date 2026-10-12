import Foundation
import OSLog

// A client that exits while a code is being written must not take the helper down.
signal(SIGPIPE, SIG_IGN)

let cleanupResult = OrphanedArtifactCleanup.run()
Logger(
    subsystem: "gr.klianos.bifrost.helper",
    category: "VPNLifecycle"
).info(
    "Removed \(cleanupResult.runtimeFiles) orphaned runtime files and \(cleanupResult.resolverFiles) orphaned resolver files"
)

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
