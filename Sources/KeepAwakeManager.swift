import Foundation
import Combine

/// Represents the available strategies for preventing disk sleep.
enum KeepAwakeStrategy: String, CaseIterable, Identifiable, Codable {
    case pmset
    case fileWrite
    
    var id: String { self.rawValue }
    
    /// A human-readable display name for the strategy.
    var displayName: String {
        switch self {
        case .pmset: return "Prevent System Sleep (Global)"
        case .fileWrite: return "Periodic File Write (Per-Drive)"
        }
    }
}

/// Manages the application's core logic for keeping drives awake.
///
/// This class handles:
/// - State management for enabled strategies.
/// - Persistence of user settings via `UserDefaults`.
/// - Execution of file writes and system commands (`pmset`) to prevent sleep.
class KeepAwakeManager: ObservableObject {
    
    /// The set of currently enabled keep-awake strategies.
    ///
    /// Changes to this property are automatically persisted.
    @Published var enabledStrategies: Set<KeepAwakeStrategy> = [.fileWrite] {
        didSet {
            saveSettings()
        }
    }
    
    /// The interval (in seconds) between file write operations.
    ///
    /// Changes to this property are automatically persisted.
    @Published var writeInterval: TimeInterval = 60 {
        didSet {
            saveSettings()
        }
    }
    
    /// A master toggle for the application's monitoring state.
    ///
    /// When set to `false`, all monitoring activities (timers, pmset assertions) are stopped immediately.
    /// Changes to this property are automatically persisted.
    @Published var isGlobalEnabled: Bool = true {
        didSet {
            if !isGlobalEnabled {
                stopAll()
            }
            saveSettings()
        }
    }
    
    private var timers: [String: Timer] = [:]
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
    }
    
    // MARK: - Persistence Keys
    
    private let kEnabledStrategies = "KeepDiskAlive_EnabledStrategies"
    private let kWriteInterval = "KeepDiskAlive_WriteInterval"
    private let kGlobalEnabled = "KeepDiskAlive_GlobalEnabled"
    
    // MARK: - File Constants
    
    private let keepAwakeFileName = ".keepdiskalive.txt"
    
    /// Persists the current configuration to `UserDefaults`.
    private func saveSettings() {
        let strategyRawValues = enabledStrategies.map { $0.rawValue }
        UserDefaults.standard.set(strategyRawValues, forKey: kEnabledStrategies)
        UserDefaults.standard.set(writeInterval, forKey: kWriteInterval)
        UserDefaults.standard.set(isGlobalEnabled, forKey: kGlobalEnabled)
    }
    
    /// Loads the configuration from `UserDefaults`.
    private func loadSettings() {
        if let savedStrategies = UserDefaults.standard.stringArray(forKey: kEnabledStrategies) {
            enabledStrategies = Set(savedStrategies.compactMap { KeepAwakeStrategy(rawValue: $0) })
            if enabledStrategies.isEmpty {
                enabledStrategies = [.fileWrite]
            }
        }
        
        let savedInterval = UserDefaults.standard.double(forKey: kWriteInterval)
        if savedInterval > 0 {
            writeInterval = savedInterval
        }
        
        if UserDefaults.standard.object(forKey: kGlobalEnabled) != nil {
            isGlobalEnabled = UserDefaults.standard.bool(forKey: kGlobalEnabled)
        }
    }
    
    // MARK: - Strategy Management
    
    /// Toggles the specified strategy on or off.
    ///
    /// Ensures that at least one strategy remains enabled unless explicitly modified.
    /// If the `pmset` strategy is disabled, it immediately reverts system settings to default.
    ///
    /// - Parameter strategy: The strategy to toggle.
    func toggleStrategy(_ strategy: KeepAwakeStrategy) {
        if enabledStrategies.contains(strategy) {
            if enabledStrategies.count > 1 {
                enabledStrategies.remove(strategy)
                
                if strategy == .pmset {
                     runPmset(value: 10)
                }
            }
        } else {
            enabledStrategies.insert(strategy)
        }
        saveSettings()
    }
    
    /// Updates the keep-awake state for all connected disks based on current settings.
    ///
    /// This method reconciles the global settings with per-disk toggles:
    /// 1. If `pmset` is enabled: Checks if *any* drive is active and adjusts system sleep accordingly.
    /// 2. If `fileWrite` is enabled: Starts or stops write timers for specific drives.
    ///
    /// - Parameter disks: The list of currently connected disks.
    func updateState(for disks: [DiskMonitor.DiskInfo]) {
        saveSettings()
        
        guard isGlobalEnabled else {
            stopAll()
            return
        }
        
        if enabledStrategies.contains(.pmset) {
            let anyEnabled = disks.contains { $0.isKeepAwakeEnabled }
            runPmset(value: anyEnabled ? 0 : 10)
        }
        
        for disk in disks {
            if disk.isKeepAwakeEnabled {
                if enabledStrategies.contains(.fileWrite) {
                    enableFileWrite(for: disk)
                } else {
                    disableFileWrite(for: disk)
                }
            } else {
                disableFileWrite(for: disk)
            }
        }
    }
    
    // MARK: - File Operations
    
    private func enableFileWrite(for disk: DiskMonitor.DiskInfo) {
        if timers[disk.path] == nil {
            startFileWrite(for: disk)
        }
    }
    
    private func disableFileWrite(for disk: DiskMonitor.DiskInfo) {
         timers[disk.path]?.invalidate()
         timers[disk.path] = nil
         
         let fileURL = URL(fileURLWithPath: disk.path).appendingPathComponent(keepAwakeFileName)
         
         if FileManager.default.fileExists(atPath: fileURL.path) {
             try? FileManager.default.removeItem(at: fileURL)
         }
    }
    
    private func startFileWrite(for disk: DiskMonitor.DiskInfo) {
        let timer = Timer.scheduledTimer(withTimeInterval: writeInterval, repeats: true) { _ in
            self.performWrite(to: disk)
        }
        timers[disk.path] = timer
        performWrite(to: disk)
    }
    
    private func performWrite(to disk: DiskMonitor.DiskInfo) {
        let fileURL = URL(fileURLWithPath: disk.path).appendingPathComponent(keepAwakeFileName)
        do {
            let content = "KeepDiskAlive is keeping this drive awake. Updated: \(Date())\n"
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write to \(disk.path): \(error)")
        }
    }
    
    // MARK: - System Operations
    
    /// Executes the `pmset` command to configure system disk sleep.
    ///
    /// - Parameter value: The disk sleep value in minutes (0 means never sleep).
    private func runPmset(value: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard self != nil else { return }
            
            if let current = AppUtils.getCurrentDiskSleep(), current == value {
                return
            }
            
            let command = "pmset -a disksleep \(value)"
            AppUtils.executeWithAdminPrivileges(command)
        }
    }
    
    /// Stops all monitoring activities and cleans up resources.
    ///
    /// This method:
    /// - Invalidates all active write timers.
    /// - Deletes all temporary keep-awake files.
    /// - Reverts global `pmset` settings to default (10 minutes).
    func stopAll() {
        for (path, timer) in timers {
            timer.invalidate()
            
             let fileURL = URL(fileURLWithPath: path).appendingPathComponent(keepAwakeFileName)
             
             do {
                 if FileManager.default.fileExists(atPath: fileURL.path) {
                     try FileManager.default.removeItem(at: fileURL)
                 }
             } catch {
                 print("Failed to clean up file at \(path): \(error)")
             }
        }
        timers.removeAll()
        
        if enabledStrategies.contains(.pmset) {
            runPmset(value: 10)
        }
    }
    
    /// Performs a graceful shutdown of the manager.
    ///
    /// Simulates `stopAll` but ensures operations (like file deletion) are attempted synchronously
    /// where possible to guarantee cleanup before the application terminates.
    func shutdown() {
        for (path, timer) in timers {
            timer.invalidate()
            let fileURL = URL(fileURLWithPath: path).appendingPathComponent(keepAwakeFileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        timers.removeAll()
        
        if enabledStrategies.contains(.pmset) {
            let value = 10
            if let current = AppUtils.getCurrentDiskSleep(), current == value {
                return
            } else {
                let command = "pmset -a disksleep \(value)"
                AppUtils.executeWithAdminPrivileges(command)
            }
        }
    }
}
