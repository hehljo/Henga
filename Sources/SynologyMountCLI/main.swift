import Foundation
#if canImport(SynologyMountCore)
import SynologyMountCore
#endif

@main
struct SynologyMountCLI {
    static func main() async {
        print("--- \(AppConfig.brandName) CLI (v\(AppConfig.appVersion)) ---")
        
        let profiles = ProfileManager.shared.getProfiles()
        print("Geladene Profile: \(profiles.count)")
        
        for p in profiles {
            print("Profile: \(p.name) (\(p.cleanHost)) - Shares: \(p.shares.count)")
            for s in p.shares {
                let target = MountPointSanitizer.resolveMountPoint(for: s)
                print("  -> Share: \(s.name) [\(s.cleanRemotePath)] => Ziel: \(target)")
            }
        }
        
        print("Status-Prüfung abgeschlossen.")
    }
}
