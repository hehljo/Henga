import Foundation

#if os(macOS)
import ServiceManagement

public final class LaunchAtLoginHelper: @unchecked Sendable {
    public static let shared = LaunchAtLoginHelper()
    
    public init() {}
    
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    public func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return true
            } catch {
                print("[SynologyMount] ⚠️ Fehler beim Ändern des Autostart-Status: \(error.localizedDescription)")
                return false
            }
        }
        return false
    }
}
#endif
