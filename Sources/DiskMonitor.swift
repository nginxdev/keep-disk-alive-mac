import Foundation
import AppKit
import Combine

/// Monitors connected storage devices and manages their keep-awake state.
class DiskMonitor: ObservableObject {
    
    /// A list of currently connected and actively monitored disks.
    ///
    /// This list filters out internal system drives and the root filesystem to ensure safety.
    @Published var connectedDisks: [DiskInfo] = []
    
    /// Represents information about a connected disk.
    struct DiskInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let path: String
        let capacity: Int64
        var isKeepAwakeEnabled: Bool = false
    }
    
    private let kSavedDiskStates = "KeepDiskAlive_SavedDiskStates"
    
    // MARK: - Initialization
    
    init() {
        startMonitoring()
        refreshDisks()
    }
    
    // MARK: - Monitoring Logic
    
    /// Sets up observers for system mount and unmount notifications.
    private func startMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumeDidMount),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumeDidUnmount),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }
    
    @objc private func volumeDidMount(_ notification: Notification) {
        refreshDisks()
    }
    
    @objc private func volumeDidUnmount(_ notification: Notification) {
        refreshDisks()
    }
    
    /// Refreshes the list of connected disks.
    ///
    /// This method:
    /// - Queries valid mount points.
    /// - Filters out internal drives and the boot volume.
    /// - Restores "Keep Awake" state from `UserDefaults` for recognized unique disks.
    private func refreshDisks() {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeTotalCapacityKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey
        ]
        
        let mountedVolumeURLs = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        
        var newDisks: [DiskInfo] = []
        let savedStates = UserDefaults.standard.dictionary(forKey: kSavedDiskStates) as? [String: Bool] ?? [:]
        
        for url in mountedVolumeURLs {
            guard let resources = try? url.resourceValues(forKeys: Set(keys)),
                  let name = resources.volumeName,
                  let capacity = resources.volumeTotalCapacity,
                  let isInternal = resources.volumeIsInternal else {
                continue
            }
            
            let isRoot = resources.volumeIsRootFileSystem ?? false
            
            if !isInternal && !isRoot {
                let uuid = resources.volumeUUIDString ?? url.path
                
                // Restore state logic:
                // 1. Maintain current runtime state if disk exists in memory.
                // 2. Fallback to persisted state from UserDefaults.
                // 3. Default to false.
                var isEnabled = false
                if let existing = connectedDisks.first(where: { $0.id == uuid }) {
                    isEnabled = existing.isKeepAwakeEnabled
                } else if let saved = savedStates[uuid] {
                    isEnabled = saved
                }
                
                let disk = DiskInfo(
                    id: uuid,
                    name: name,
                    path: url.path,
                    capacity: Int64(capacity),
                    isKeepAwakeEnabled: isEnabled
                )
                newDisks.append(disk)
            }
        }
        
        DispatchQueue.main.async {
            self.connectedDisks = newDisks
        }
    }
    
    // MARK: - State Management
    
    /// Toggles the keep-awake state for a specific disk.
    ///
    /// The new state is immediately persisted to `UserDefaults`.
    ///
    /// - Parameter diskPath: The file system path of the disk to toggle.
    func toggleKeepAwake(for diskPath: String) {
        if let index = connectedDisks.firstIndex(where: { $0.path == diskPath }) {
            connectedDisks[index].isKeepAwakeEnabled.toggle()
            saveState(for: connectedDisks[index])
        }
    }
    
    /// Persists the state of a disk to `UserDefaults`.
    private func saveState(for disk: DiskInfo) {
        var savedStates = UserDefaults.standard.dictionary(forKey: kSavedDiskStates) as? [String: Bool] ?? [:]
        savedStates[disk.id] = disk.isKeepAwakeEnabled
        UserDefaults.standard.set(savedStates, forKey: kSavedDiskStates)
    }
}
