import Foundation
import OSLog

let cleanupResult = OrphanedArtifactCleanup.run()
Logger(
    subsystem: "com.klianos.VPNConfigurator.helper",
    category: "VPNLifecycle"
).info(
    "Removed \(cleanupResult.runtimeFiles) orphaned runtime files and \(cleanupResult.resolverFiles) orphaned resolver files"
)

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
