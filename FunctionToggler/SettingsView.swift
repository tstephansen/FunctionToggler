//
//  SettingsView.swift
//  FunctionToggler
//
//  Created by Tim Stephansen on 3/25/26.
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showingAppPicker = false
    @State private var hasAccessibility = AXIsProcessTrusted()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            Divider()

            globalDefaultSection
                .padding()

            Divider()

            Text("Per-App Rules")
                .font(.headline)
                .padding([.horizontal, .top])

            Text("Apps listed here override the global default.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            appRulesList

            Divider()
            
            HStack {
                Button(action: { showingAppPicker = true }) {
                    Label("Add App", systemImage: "plus")
                }
                Spacer()
                Button(action: {
                    requestAccessibilityPermissionIfNeeded()
                }) {
                    Label(
                        hasAccessibility ? "Accessibility Enabled" : "Enable Accessibility",
                        systemImage: hasAccessibility ? "lock.open" : "lock"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 14)
                    .foregroundStyle(accessibilityButtonForegroundColor)
                    .background(accessibilityButtonBackgroundColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(hasAccessibility)
                .padding()
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    refreshAccessibilityStatus()
                }
                Spacer()
                HStack {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { store.startAtLogin },
                        set: { store.setStartAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.subheadline.bold())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

        }
        .frame(minWidth: 480, minHeight: 420)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView { rule in
                store.addRule(rule)
            }
        }
    }
    
    // MARK: - Accessibility
    
    private func refreshAccessibilityStatus() {
        hasAccessibility = AXIsProcessTrusted()
    }
    
    private func requestAccessibility() {
        if !checkAccessibilityPermission() {
            print("⚠️  Accessibility permission not granted. Window detection will not work until permission is enabled in System Settings → Privacy & Security → Accessibility.")
            requestAccessibilityPermissionIfNeeded()
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    private var accessibilityButtonBackgroundColor: Color {
        hasAccessibility ? Color.green : Color.red.opacity(0.8)
    }

    private var accessibilityButtonForegroundColor: Color {
        if hasAccessibility {
            return colorScheme == .dark ? .white : .black
        } else {
            return .white
        }
    }

    // MARK: - Sub-views

    private var headerSection: some View {
        HStack {
            Image("MainIcon")
            VStack(alignment: .leading) {
                Text("Function Toggler")
                    .font(.title2.bold())
                Text("Automatically toggle function keys per app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: $store.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding()
    }

    private var globalDefaultSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Global Default")
                    .font(.subheadline.bold())
                Text("Used for apps without a specific rule")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: $store.defaultUseFnAsStandard) {
                Text("Media Keys (F1–F12 = brightness, volume, etc.)")
                    .tag(false)
                Text("Standard Function Keys (F1–F12)")
                    .tag(true)
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var appRulesList: some View {
        List {
            ForEach(store.appRules) { rule in
                HStack {
                    if let icon = iconForBundleID(rule.bundleID) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "app")
                            .frame(width: 24, height: 24)
                    }

                    VStack(alignment: .leading) {
                        Text(rule.appName)
                            .font(.body)
                        Text(rule.bundleID)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(rule.useFnAsStandard ? "Fn Keys" : "Media Keys")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rule.useFnAsStandard
                                      ? Color.blue.opacity(0.15)
                                      : Color.gray.opacity(0.15))
                        )

                    Toggle("", isOn: Binding(
                        get: { rule.useFnAsStandard },
                        set: { newValue in
                            if let idx = store.appRules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
                                store.appRules[idx].useFnAsStandard = newValue
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()

                    Button {
                        store.removeRule(bundleID: rule.bundleID)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove rule")
                }
                .padding(.vertical, 2)
            }
            .onDelete(perform: store.removeRules)
        }
        .listStyle(.inset)
        .frame(minHeight: 120)
    }

    // MARK: - Helpers

    private func iconForBundleID(_ bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - App Picker Sheet

struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (AppRule) -> Void

    @State private var runningApps: [AppInfo] = []
    @State private var selectedBundleID: String?
    @State private var useFnAsStandard = true
    @State private var searchText = ""

    struct AppInfo: Identifiable, Hashable {
        var id: String { bundleID }
        var bundleID: String
        var name: String
        var icon: NSImage?
    }

    var filteredApps: [AppInfo] {
        if searchText.isEmpty { return runningApps }
        return runningApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Select an Application")
                .font(.headline)
                .padding()

            TextField("Search…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filteredApps, selection: $selectedBundleID) { app in
                HStack {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading) {
                        Text(app.name)
                        Text(app.bundleID)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .tag(app.bundleID)
            }

            Divider()

            HStack {
                Picker("Behavior:", selection: $useFnAsStandard) {
                    Text("Standard Function Keys").tag(true)
                    Text("Media Keys").tag(false)
                }
                .frame(maxWidth: 320)

                Spacer()

                Button("Browse…") { browseForApp() }

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Add") {
                    guard let bid = selectedBundleID,
                          let app = runningApps.first(where: { $0.bundleID == bid }) else { return }
                    let rule = AppRule(
                        bundleID: app.bundleID,
                        appName: app.name,
                        useFnAsStandard: useFnAsStandard
                    )
                    onAdd(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBundleID == nil)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear(perform: loadInstalledApps)
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundle = Bundle(url: url),
              let bid = bundle.bundleIdentifier else { return }

        let name = url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let appInfo = AppInfo(bundleID: bid, name: name, icon: icon)

        if !runningApps.contains(where: { $0.bundleID == bid }) {
            runningApps.append(appInfo)
            runningApps.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        selectedBundleID = bid
    }

    private func loadInstalledApps() {
        var seen = Set<String>()
        var apps: [AppInfo] = []

        for app in NSWorkspace.shared.runningApplications {
            guard let bid = app.bundleIdentifier,
                  app.activationPolicy == .regular,
                  !seen.contains(bid) else { continue }
            seen.insert(bid)
            apps.append(AppInfo(
                bundleID: bid,
                name: app.localizedName ?? bid,
                icon: app.icon
            ))
        }

        let fm = FileManager.default
        let appFolders = [
            "/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        for folder in appFolders {
            guard let contents = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = (folder as NSString).appendingPathComponent(item)
                if let bundle = Bundle(path: path),
                   let bid = bundle.bundleIdentifier,
                   !seen.contains(bid) {
                    seen.insert(bid)
                    let name = (item as NSString).deletingPathExtension
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    apps.append(AppInfo(bundleID: bid, name: name, icon: icon))
                }
            }
        }

        runningApps = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 520, height: 600)
}
