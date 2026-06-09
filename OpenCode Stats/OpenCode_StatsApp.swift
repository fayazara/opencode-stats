//
//  OpenCode_StatsApp.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import SwiftUI
import Combine
import UserNotifications

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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellable: AnyCancellable?
    let updaterManager = UpdaterManager()

    private let normalIcon: NSImage = {
        let img = NSImage(named: "menubar-icon") ?? NSImage()
        img.size = NSSize(width: 14, height: 18)
        img.isTemplate = true
        return img
    }()

    private let iconSize = NSSize(width: 14, height: 18)

    private func iconTinted(_ color: NSColor) -> NSImage {
        let img = NSImage(size: iconSize)
        img.lockFocus()
        let rect = NSRect(origin: .zero, size: iconSize)
        normalIcon.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        img.unlockFocus()
        return img
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Re-check budget styling immediately when user changes budget values in Settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(budgetDefaultsChanged),
            name: .budgetSettingsChanged,
            object: nil
        )

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if !granted {
                print("Budget notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }

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
                self?.updateMenuBarCost(stats)
            }

        // Start database monitoring for live menu bar updates
        OpenCodeDatabase.shared.startMonitoring()

        // Start Sparkle updater
        updaterManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        OpenCodeDatabase.shared.stopMonitoring()
    }

    private func updateMenuBarCost(_ stats: OpenCodeStats) {
        guard let button = statusItem.button else { return }
        let cost = stats.todayCost
        if cost > 0 {
            let formatted = String(format: "$%.2f", cost)
            button.title = " \(formatted)"
        } else {
            button.title = ""
        }
        applyBudgetStyling(stats)
    }

    private func applyBudgetStyling(_ stats: OpenCodeStats) {
        guard let button = statusItem.button else { return }

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "budgetAlertsEnabled") else {
            button.image = normalIcon
            return
        }

        let calculator = BudgetCalculator(
            dailyBudget: defaults.double(forKey: "dailyBudget"),
            monthlyBudget: defaults.double(forKey: "monthlyBudget"),
            todayCost: stats.todayCost,
            monthlyCost: OpenCodeDatabase.shared.totalCostForCurrentMonth()
        )

        switch calculator.overallLevel {
        case .exceeded:
            button.image = iconTinted(NSColor.orange)
        case .approaching:
            button.image = iconTinted(NSColor(calibratedRed: 1, green: 0.84, blue: 0, alpha: 1))
        case .none:
            button.image = normalIcon
        }

        let todayKey = "budgetNotifiedDaily-\(todayDateKey())"
        if calculator.dailyLevel.isExceeded && !defaults.bool(forKey: todayKey) {
            defaults.set(true, forKey: todayKey)
            sendBudgetNotification(
                title: "OpenCode Stats — Daily Budget Exceeded",
                body: String(format: "Daily budget of $%.2f exceeded ($%.2f so far today).", calculator.dailyBudget, calculator.todayCost)
            )
        }

        let monthKey = "budgetNotifiedMonthly-\(monthDateKey())"
        if calculator.monthlyLevel.isExceeded && !defaults.bool(forKey: monthKey) {
            defaults.set(true, forKey: monthKey)
            sendBudgetNotification(
                title: "OpenCode Stats — Monthly Budget Exceeded",
                body: String(format: "Monthly budget of $%.2f exceeded ($%.2f so far this month).", calculator.monthlyBudget, calculator.monthlyCost)
            )
        }
    }

    private func todayDateKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func monthDateKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: Date())
    }

    private func sendBudgetNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    @objc private func budgetDefaultsChanged() {
        updateMenuBarCost(OpenCodeDatabase.shared.stats)
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

extension Notification.Name {
    static let budgetSettingsChanged = Notification.Name("budgetSettingsChanged")
}
