import SwiftUI

/// A secondary settings view for the application.
///
/// Note: The primary settings interface is currently embedded directly within `MenuContent`
/// for easier access in the menu bar popover. This view remains as a standalone component
/// for potential future use (e.g., in a separate preferences window).
struct SettingsView: View {
    @ObservedObject var keepAwakeManager: KeepAwakeManager
    
    var body: some View {
        Form {
            Section(header: Text("Strategy")) {
                ForEach(KeepAwakeStrategy.allCases) { strategy in
                    Toggle(strategy.displayName, isOn: Binding(
                        get: { keepAwakeManager.enabledStrategies.contains(strategy) },
                        set: { _ in keepAwakeManager.toggleStrategy(strategy) }
                    ))
                    .disabled(keepAwakeManager.enabledStrategies.count == 1 && keepAwakeManager.enabledStrategies.contains(strategy))
                }
                
                if keepAwakeManager.enabledStrategies.contains(.pmset) {
                    Text("⚠️ Warning: This strategy uses 'sudo pmset' which applies GLOBALLY to all connected drives.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if keepAwakeManager.enabledStrategies.contains(.fileWrite) {
                Section(header: Text("File Write Configuration")) {
                    HStack {
                        Text("Write Interval:")
                        Slider(value: $keepAwakeManager.writeInterval, in: 1...300, step: 1)
                        Text("\(Int(keepAwakeManager.writeInterval))s")
                            .monospacedDigit()
                    }
                }
            }
            
            Section {
                Button("Quit KeepDiskAlive") {
                    keepAwakeManager.shutdown()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
}
