//
//  main.swift
//  AI-Vision (v2 with Menu)
//
//  Created by Gemini on 8/2/2025.
//  Copyright © 2025 Gemini. All rights reserved.
//
//  This script creates the menu bar item and menu, allowing the user
//  to trigger the AI vision core script.

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    let coreScriptPath = "\(NSHomeDirectory())/AI-Vision/ai_vision_core.py"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "eye.circle.fill", accessibilityDescription: "AI-Vision")
        }
        
        // Build the menu
        setupMenu()
    }

    func setupMenu() {
        let menu = NSMenu()

        // Menu Item 1: The main action
        let askItem = NSMenuItem(title: "Ask with Voice & Vision", action: #selector(runCoreScript), keyEquivalent: "a")
        askItem.target = self
        menu.addItem(askItem)

        menu.addItem(NSMenuItem.separator())

        // Menu Item 2: Quit the application
        let quitItem = NSMenuItem(title: "Quit AI-Vision", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusBarItem.menu = menu
    }

    @objc func runCoreScript() {
        // We run the Python script in the background so it doesn't freeze the UI.
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            // Using /usr/bin/env to find python3 in the user's PATH
            task.launchPath = "/usr/bin/env"
            task.arguments = ["python3", self.coreScriptPath]

            // Optional: Capture output for debugging
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            task.launch()
            
            // Log output for debugging purposes
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Core script output:\n\(output)")
            }
            
            task.waitUntilExit()
        }
    }
}

// --- Main Application Setup ---
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
