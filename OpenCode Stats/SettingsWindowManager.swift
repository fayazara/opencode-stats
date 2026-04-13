//
//  SettingsWindowManager.swift
//  OpenCode Stats
//
//  Created by Codex on 10/04/26.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    private lazy var windowController: NSWindowController = {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "OpenCode Stats Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(width: 520, height: 420)
        window.maxSize = NSSize(width: 520, height: 420)
        window.setContentSize(NSSize(width: 520, height: 420))
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        return NSWindowController(window: window)
    }()

    private override init() {}

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
