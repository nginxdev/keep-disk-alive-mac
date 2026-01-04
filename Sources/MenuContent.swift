import SwiftUI

/// The main content view for the KeepDiskAlive menu bar application.
///
/// This view coordinates the interaction between `DiskMonitor` and `KeepAwakeManager`,
/// presenting the list of drives, global controls, and configuration settings.
struct MenuContent: View {
    @ObservedObject var diskMonitor: DiskMonitor
    @ObservedObject var keepAwakeManager: KeepAwakeManager
    @Environment(\.openWindow) var openWindow
    
    // Hover States
    @State private var hoveredDisk: String?
    @State private var isHoveringQuit = false
    @State private var isHoveringSettings = false
    @State private var isSettingsExpanded = false
    
    // Layout Constants
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 12
    private let iconSize: CGFloat = 14
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Global Toggle Section
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.secondary)
                
                Text(keepAwakeManager.isGlobalEnabled ? "Monitoring Active" : "Monitoring Paused")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { keepAwakeManager.isGlobalEnabled },
                    set: { newValue in
                        withAnimation(.snappy) {
                            keepAwakeManager.isGlobalEnabled = newValue
                            keepAwakeManager.updateState(for: diskMonitor.connectedDisks)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // MARK: - Drive List Section
            if keepAwakeManager.isGlobalEnabled {
                ScrollView {
                    VStack(spacing: 0) {
                        if diskMonitor.connectedDisks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "externaldrive.badge.xmark")
                                    .font(.largeTitle)
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                Text("No Drives Connected")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            ForEach(diskMonitor.connectedDisks) { disk in
                                DiskRow(disk: disk, 
                                        isHovered: hoveredDisk == disk.id, 
                                        horizontalPadding: horizontalPadding,
                                        onToggle: {
                                    diskMonitor.toggleKeepAwake(for: disk.path)
                                    keepAwakeManager.updateState(for: diskMonitor.connectedDisks)
                                })
                                .onHover { isHovering in
                                    hoveredDisk = isHovering ? disk.id : nil
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: min(CGFloat(max(diskMonitor.connectedDisks.count, 1) * 44 + 16), 350))
            }
            
            Divider()
            
            // MARK: - Footer & Settings
            VStack(spacing: 0) {
                // Footer Controls
                HStack {
                    // Quit Button
                    Button(action: { 
                        keepAwakeManager.shutdown()
                        NSApplication.shared.terminate(nil) 
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Quit")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(isHoveringQuit ? 0.06 : 0))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringQuit = $0 }
                    
                    Spacer()
                    
                    if keepAwakeManager.isGlobalEnabled {
                        // Settings Expand/Collapse
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSettingsExpanded.toggle()
                            }
                        }) {
                             HStack(spacing: 6) {
                                Text("Settings")
                                    .font(.system(size: 12))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .rotationEffect(.degrees(isSettingsExpanded ? 90 : 0))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(isHoveringSettings ? 0.06 : 0))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringSettings = $0 }
                    }
                }
                .padding(.horizontal, horizontalPadding - 8)
                .padding(.vertical, verticalPadding - 4)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                
                // MARK: - Inline Settings Panel
                if isSettingsExpanded && keepAwakeManager.isGlobalEnabled {
                    Divider()
                        .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Strategy Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("KEEP AWAKE METHOD")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 2)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(KeepAwakeStrategy.allCases) { strategy in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle(isOn: Binding(
                                            get: { keepAwakeManager.enabledStrategies.contains(strategy) },
                                            set: { _ in keepAwakeManager.toggleStrategy(strategy) }
                                        )) {
                                            Text(strategy.displayName)
                                                .font(.system(size: 12)) 
                                        }
                                        .toggleStyle(.checkbox)
                                        .disabled(keepAwakeManager.enabledStrategies.count == 1 && keepAwakeManager.enabledStrategies.contains(strategy))
                                        
                                        // Specific Warning for Global pmset
                                        if strategy == .pmset {
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "info.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 10))
                                                    .padding(.top, 2)
                                                
                                                Text("Keeps ALL connected drives awake.")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .padding(.leading, 20)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Strategy Configuration (Timer Interval)
                        if keepAwakeManager.enabledStrategies.contains(.fileWrite) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("WRITE INTERVAL")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(keepAwakeManager.writeInterval))s")
                                        .font(.system(size: 12, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $keepAwakeManager.writeInterval, in: 1...300, step: 1)
                                    .controlSize(.mini)
                                    .tint(.blue)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 300, maxWidth: 300)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: keepAwakeManager.enabledStrategies) { _ in
            DispatchQueue.main.async {
                keepAwakeManager.updateState(for: diskMonitor.connectedDisks)
            }
        }
    }
}

/// A list row component representing a single disk in the UI.
struct DiskRow: View {
    let disk: DiskMonitor.DiskInfo
    let isHovered: Bool
    let horizontalPadding: CGFloat
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Drive Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "internaldrive")
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
            }
            
            // Drive Details
            VStack(alignment: .leading, spacing: 2) {
                Text(disk.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(formatBytes(disk.capacity))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Keep Awake Toggle
            Button(action: onToggle) {
                ZStack {
                    Capsule()
                        .fill(disk.isKeepAwakeEnabled ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 34, height: 18)
                    
                    Circle()
                        .fill(.white)
                        .padding(1.5)
                        .frame(width: 17, height: 17)
                        .offset(x: disk.isKeepAwakeEnabled ? 8 : -8)
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3), value: disk.isKeepAwakeEnabled)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
