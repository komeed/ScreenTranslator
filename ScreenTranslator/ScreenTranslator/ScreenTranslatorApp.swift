//
//  ScreenTranslatorApp.swift
//  ScreenTranslator
//
//  Created by Omeed on 2/2/25.
//

import SwiftUI
import Foundation

@main
struct ScreenTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
