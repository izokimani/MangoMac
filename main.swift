//
//  main.swift
//  AI-Vision (v3 with Logo)
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
            let logoPath = "\(NSHomeDirectory())/AI-Vision/logo.png"
            
            // Try to load the custom logo
            if let logoImage = NSImage(contentsOfFile: logoPath) {
                // Set isTemplate to true so the icon automatically adapts to light/dark mode
                logoImage.isTemplate = true
                button.image = logoImage
            } else {
                // If the logo can't be found, use a fallback system icon
                button.image = NSImage(systemSymbolName: "eye.circle.fill", accessibilityDescription: "AI-Vision")
            }
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
