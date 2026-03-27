//
//  WindowObserver.swift
//  FunctionToggler
//
//  Created by Tim Stephansen on 3/25/26.
//

import AppKit
import Combine

class WindowObserver: ObservableObject {
    @Published var currentAppName: String = "Unknown"
    @Published var currentFnState: String = "—"
    @Published var currentUseFnAsStandard: Bool?

    private var cancellable: AnyCancellable?
    private let settingsStore = SettingsStore.shared

    func start() {
        guard settingsStore.isEnabled else { return }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            handleAppChange(frontmost)
        }

        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> NSRunningApplication? in
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            }
            .sink { [weak self] app in
                self?.handleAppChange(app)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    // MARK: - Private

    private func handleAppChange(_ app: NSRunningApplication) {
        let bundleID = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? bundleID
        currentAppName = appName

        let useFnAsStandard = settingsStore.shouldUseFnAsStandard(for: bundleID)

        let desiredState = useFnAsStandard ? "on" : "off"
        currentUseFnAsStandard = useFnAsStandard
        currentFnState = useFnAsStandard ? "Yes" : "No"

        print("🔄 App changed → \(appName) (\(bundleID)) — fn standard keys: \(desiredState)")

        setFnKeysAsStandard(useFnAsStandard)
    }

    private func setFnKeysAsStandard(_ enable: Bool) {
        let value = enable ? 1 : 0
        let (out1, code1) = runShellCommand("defaults write -g com.apple.keyboard.fnState -int \(value)")
        if code1 != 0 {
            print("❌ defaults write failed (exit \(code1)): \(out1)")
        }

        let activatePath = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        if FileManager.default.fileExists(atPath: activatePath) {
            let (out2, code2) = runShellCommand("\(activatePath) -u")
            if code2 != 0 {
                print("❌ activateSettings failed (exit \(code2)): \(out2)")
            }
        } else {
            runShellCommand("launchctl kill SIGHUP user/$(id -u)/com.apple.cfprefsd")
        }
    }
    
    @discardableResult
    private func runShellCommand(_ command: String) -> (output: String, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("❌ Failed to run command: \(error.localizedDescription)")
            return ("", -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            print("⚠️  Command exited with \(process.terminationStatus): \(output)")
        }

        return (output, process.terminationStatus)
    }
}
