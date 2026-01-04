import SwiftUI

/// The entry point for the KeepDiskAlive application.
///
/// This struct configures the application as a menu bar extra (system tray icon)
/// and initializes the core data models (`DiskMonitor` and `KeepAwakeManager`).
@main
struct KeepDiskAliveApp: App {
    
    /// The manager for disk discovery and monitoring.
    @StateObject var diskMonitor = DiskMonitor()
    
    /// The manager for keep-awake strategies and persistence.
    @StateObject var keepAwakeManager = KeepAwakeManager()
    
    var body: some Scene {
        MenuBarExtra("KeepDiskAlive", systemImage: "internaldrive") {
            MenuContent(diskMonitor: diskMonitor, keepAwakeManager: keepAwakeManager)
        }
        .menuBarExtraStyle(.window)
    }
}
