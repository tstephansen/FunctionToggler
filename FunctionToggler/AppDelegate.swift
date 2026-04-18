//
//  AppDelegate.swift
//  FunctionToggler
//
//  Created by Tim Stephansen on 3/25/26.
//

import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var windowObserver: WindowObserver!
    private var settingsStore = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemIcon(useFnAsStandard: nil)

        buildMenu()

        windowObserver = WindowObserver()
        observeWindowObserver()
        windowObserver.start()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: settingsStore.isEnabled ? "● Enabled" : "○ Disabled",
            action: #selector(toggleEnabled),
            keyEquivalent: "e"
        )
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        let currentAppItem = NSMenuItem(
            title: "Current app: \(windowObserver?.currentAppName ?? "Unknown")",
            action: nil,
            keyEquivalent: ""
        )
        currentAppItem.isEnabled = false
        menu.addItem(currentAppItem)

        let fnStateItem = NSMenuItem(
            title: "Fn keys as standard: \(windowObserver?.currentFnState ?? "—")",
            action: nil,
            keyEquivalent: ""
        )
        fnStateItem.isEnabled = false
        menu.addItem(fnStateItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Function Toggler",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        menu.delegate = self
        statusItem.menu = menu
    }

    private func observeWindowObserver() {
        windowObserver.$currentUseFnAsStandard
            .receive(on: RunLoop.main)
            .sink { [weak self] useFnAsStandard in
                self?.updateStatusItemIcon(useFnAsStandard: useFnAsStandard)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemIcon(useFnAsStandard: Bool?) {
        guard let button = statusItem.button else { return }

        let imageName: String
        if let useFnAsStandard {
            imageName = useFnAsStandard ? "FunctionIcon" : "MediaIcon"
        } else {
            imageName = "MediaIcon"
        }

        button.image = NSImage(named: imageName)
        button.image?.isTemplate = false
        button.image?.size = NSSize(width: 18, height: 18)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settingsStore.isEnabled.toggle()
        buildMenu()
        if settingsStore.isEnabled {
            windowObserver.start()
        } else {
            windowObserver.stop()
        }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Function Toggler Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate (refresh status on menu open)

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }
}
