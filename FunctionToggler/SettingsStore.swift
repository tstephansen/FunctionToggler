//
//  SettingsStore.swift
//  FunctionToggler
//
//  Created by Tim Stephansen on 3/25/26.
//

import Foundation
import Combine
import SwiftUI
import ServiceManagement

struct AppRule: Codable, Identifiable, Equatable {
    var id: String { bundleID }
    var bundleID: String
    var appName: String
    var useFnAsStandard: Bool
}

class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let appRules = "appRules"
        static let defaultUseFn = "defaultUseFnAsStandard"
        static let startAtLogin = "startAtLogin"
    }

    // MARK: - Published Properties

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var defaultUseFnAsStandard: Bool {
        didSet { defaults.set(defaultUseFnAsStandard, forKey: Keys.defaultUseFn) }
    }

    @Published var appRules: [AppRule] {
        didSet { saveRules() }
    }
    
    @Published var startAtLogin: Bool {
        didSet { defaults.set(startAtLogin, forKey: Keys.startAtLogin)}
    }

    // MARK: - Init

    private init() {
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.defaultUseFnAsStandard = defaults.object(forKey: Keys.defaultUseFn) as? Bool ?? false
        self.startAtLogin = defaults.object(forKey: Keys.startAtLogin) as? Bool ?? false

        if let data = defaults.data(forKey: Keys.appRules),
           let rules = try? JSONDecoder().decode([AppRule].self, from: data) {
            self.appRules = rules
        } else {
            self.appRules = []
        }
    }

    // MARK: - Helpers

    func shouldUseFnAsStandard(for bundleID: String) -> Bool {
        if let rule = appRules.first(where: { $0.bundleID == bundleID }) {
            return rule.useFnAsStandard
        }
        return defaultUseFnAsStandard
    }

    func addRule(_ rule: AppRule) {
        if let idx = appRules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            appRules[idx] = rule
        } else {
            appRules.append(rule)
        }
    }

    func removeRules(at offsets: IndexSet) {
        appRules.remove(atOffsets: offsets)
    }

    func removeRule(bundleID: String) {
        appRules.removeAll { $0.bundleID == bundleID }
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(appRules) {
            defaults.set(data, forKey: Keys.appRules)
        }
    }
    
    func refresh() {
        if #available(macOS 13.0, *) {
            startAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            startAtLogin = false
        }
    }
    
    func setStartAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            print("Failed to update launch-at-login setting: \(error)")
            refresh()
        }
    }
}
