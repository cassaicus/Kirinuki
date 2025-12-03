//
//  KirinukiApp.swift
//  Kirinuki
//
//

import SwiftUI

@main
struct KirinukiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            SidebarCommands() // Standard sidebar menu

            CommandGroup(replacing: .newItem) {
                // Remove New Window etc if not needed, or just add Open Folder
            }

            CommandGroup(after: .newItem) {
                Button("Open Folder...") {
                    // Send notification or use a global manager.
                    // Since ImageManager is inside ContentView, we need a way to reach it.
                    // A common pattern is EnvironmentObject or NotificationCenter.
                    NotificationCenter.default.post(name: Notification.Name("OpenFolderCommand"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Export...") {
                    NotificationCenter.default.post(name: Notification.Name("ExportCommand"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
