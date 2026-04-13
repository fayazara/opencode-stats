//
//  OpenCode_StatsApp.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import SwiftUI
import Combine

@main
struct OpenCode_StatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowManager.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellable: AnyCancellable?
    let updaterManager = UpdaterManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = PopoverHostingController(
            rootView: StatsView()
        )

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "menubar-icon")
            icon?.size = NSSize(width: 14, height: 18)
            button.image = icon
            button.imagePosition = .imageLeading
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe today's cost and update menu bar text
        cancellable = OpenCodeDatabase.shared.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.updateMenuBarCost(stats.todayCost)
            }

        // Start database monitoring for live menu bar updates
        OpenCodeDatabase.shared.startMonitoring()

        // Start Sparkle updater
        updaterManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        OpenCodeDatabase.shared.stopMonitoring()
    }

    private func updateMenuBarCost(_ cost: Double) {
        guard let button = statusItem.button else { return }
        if cost > 0 {
            let formatted = String(format: "$%.2f", cost)
            button.title = " \(formatted)"
        } else {
            button.title = ""
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent, let button = statusItem.button else { return }

        if event.type == .rightMouseUp {
            // Show context menu
            let menu = NSMenu()

            let aboutItem = NSMenuItem(title: "About OpenCode Stats", action: #selector(openAbout), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)

            menu.addItem(NSMenuItem.separator())

            let githubItem = NSMenuItem(title: "GitHub Repository", action: #selector(openGitHub), keyEquivalent: "")
            githubItem.target = self
            menu.addItem(githubItem)

            let twitterItem = NSMenuItem(title: "Follow @fayazara", action: #selector(openTwitter), keyEquivalent: "")
            twitterItem.target = self
            menu.addItem(twitterItem)

            menu.addItem(NSMenuItem.separator())

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)

            let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
            updateItem.target = self
            menu.addItem(updateItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit OpenCode Stats", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)

            statusItem.menu = menu
            button.performClick(nil)
            // Clear menu so left-click popover works again
            statusItem.menu = nil
        } else {
            // Left click: toggle popover
            if popover.isShown {
                popover.performClose(nil)
            } else {
                OpenCodeDatabase.shared.setPopoverVisible(true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    @objc private func openSettings() {
        SettingsWindowManager.shared.show()
    }

    @objc private func checkForUpdates() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        updaterManager.checkForUpdates()
        // Switch back to accessory after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func openAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "OpenCode Stats",
            .credits: NSAttributedString(
                string: "Made by Fayaz Ahmed\nhttps://x.com/fayazara\nhttps://github.com/fayazara/opencode-stats",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/fayazara/opencode-stats")!)
    }

    @objc private func openTwitter() {
        NSWorkspace.shared.open(URL(string: "https://x.com/fayazara")!)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        OpenCodeDatabase.shared.setPopoverVisible(false)
    }
}
