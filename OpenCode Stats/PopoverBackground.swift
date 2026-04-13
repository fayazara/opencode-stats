//
//  PopoverBackground.swift
//  OpenCode Stats
//
//  Created by Codex on 12/04/26.
//

import AppKit
import SwiftUI

enum PopoverAppearance {
    static let backgroundColor = NSColor(name: "PopoverBackground") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        if isDark {
            return NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.13, alpha: 1)
        }

        return NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.96, alpha: 1)
    }
}

final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidAppear() {
        super.viewDidAppear()
        installFrameBackground()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        installFrameBackground()
    }

    private func installFrameBackground() {
        guard let frameView = view.window?.contentView?.superview else { return }

        if let existingBackground = frameView.subviews.compactMap({ $0 as? PopoverBackgroundView }).first {
            existingBackground.frame = frameView.bounds
            existingBackground.needsDisplay = true
            return
        }

        let backgroundView = PopoverBackgroundView(frame: frameView.bounds)
        backgroundView.autoresizingMask = [.width, .height]
        frameView.addSubview(backgroundView, positioned: .below, relativeTo: nil)
    }
}

final class PopoverBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        PopoverAppearance.backgroundColor.setFill()
        bounds.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
