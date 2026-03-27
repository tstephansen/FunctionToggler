//
//  FunctionTogglerApp.swift
//  FunctionToggler
//
//  Created by Tim Stephansen on 3/25/26.
//

import SwiftUI

@main
struct FnKeyTogglerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
