import Foundation
import AppKit

/// Utility functions for system interactions and shell command execution.
struct AppUtils {
    
    /// Checks if the current process is running with root privileges.
    /// - Returns: `true` if the process has root access (uid 0), `false` otherwise.
    static func isRoot() -> Bool {
        return getuid() == 0
    }

    /// Executes a shell command with administrator privileges using `osascript`.
    ///
    /// This method leverages AppleScript to prompt the user for credentials if required.
    /// It runs the command synchronously on a background thread (due to `process.waitUntilExit()`)
    /// but safely handles the `Process` environment.
    ///
    /// - Parameter command: The simple shell string to execute (e.g., "pmset -a disksleep 0").
    static func executeWithAdminPrivileges(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(command)\" with administrator privileges"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to execute osascript: \(error)")
        }
    }
    
    /// reads the current system "disksleep" value via `pmset -g`.
    ///
    /// - Returns: The current sleep setting in minutes, or `nil` if parsing fails.
    static func getCurrentDiskSleep() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse output looking for "disksleep <number>"
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("disksleep") {
                        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if let last = parts.last, let value = Int(last) {
                            return value
                        }
                    }
                }
            }
        } catch {
            print("Failed to read pmset: \(error)")
        }
        return nil
    }
}
