//
//  Helpers.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import Foundation
import Combine
import SwiftUI
import AppKit

enum Formatters {
    static func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func tokens(_ value: Int64) -> String {
        let d = Double(value)
        if d >= 1_000_000_000 {
            return String(format: "%.1fB", d / 1_000_000_000)
        } else if d >= 1_000_000 {
            return String(format: "%.1fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.1fK", d / 1_000)
        }
        return "\(value)"
    }

    static func tokens(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percentage(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.1f%%", value)
        }
        return String(format: "%.1f%%", value)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

enum OpenCodePreferenceKey {
    static let preferredTerminal = "preferredTerminal"
}

enum PreferredTerminal: String, CaseIterable, Identifiable {
    case terminal
    case iTerm2
    case ghostty
    case cmux

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: "Terminal"
        case .iTerm2: "iTerm2"
        case .ghostty: "Ghostty"
        case .cmux: "Cmux"
        }
    }

    var bundleIdentifier: String {
        bundleIdentifiers[0]
    }

    var bundleIdentifiers: [String] {
        switch self {
        case .terminal: ["com.apple.Terminal"]
        case .iTerm2: ["com.googlecode.iterm2"]
        case .ghostty: ["com.mitchellh.ghostty"]
        case .cmux: ["com.cmuxterm.app", "com.cmuxterm.app.debug"]
        }
    }

    var subtitle: String {
        switch self {
        case .terminal:
            "Opens a new Terminal window in the project directory and runs the selected OpenCode command."
        case .iTerm2:
            "Opens a new iTerm2 window with your default profile and runs the selected OpenCode command."
        case .ghostty:
            "Opens a new Ghostty window in the project directory, types the command, and presses Return."
        case .cmux:
            "Opens a new Cmux window, moves into the project directory, and runs the selected OpenCode command."
        }
    }

    var isInstalled: Bool {
        installedBundleIdentifier != nil
    }

    var installedBundleIdentifier: String? {
        bundleIdentifiers.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    static var current: PreferredTerminal {
        guard let rawValue = UserDefaults.standard.string(forKey: OpenCodePreferenceKey.preferredTerminal),
              let terminal = PreferredTerminal(rawValue: rawValue) else {
            return .terminal
        }
        return terminal
    }
}

enum ProjectOpenApp: String, CaseIterable, Identifiable {
    case cursor
    case vsCode
    case windsurf
    case zed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .vsCode: "VS Code"
        case .windsurf: "Windsurf"
        case .zed: "Zed"
        }
    }

    var bundleIdentifiers: [String] {
        switch self {
        case .cursor:
            [
                "com.todesktop.230313mzl4w4u92",
                "com.anysphere.cursor",
                "com.cursor.Cursor"
            ]
        case .vsCode:
            [
                "com.microsoft.VSCode",
                "com.microsoft.VSCodeInsiders"
            ]
        case .windsurf:
            [
                "com.exafunction.windsurf",
                "com.exafunction.windsurfNext"
            ]
        case .zed:
            [
                "dev.zed.Zed",
                "dev.zed.Zed-Preview"
            ]
        }
    }

    private var fallbackApplicationPaths: [String] {
        switch self {
        case .cursor:
            ["/Applications/Cursor.app"]
        case .vsCode:
            [
                "/Applications/Visual Studio Code.app",
                "/Applications/Visual Studio Code - Insiders.app"
            ]
        case .windsurf:
            [
                "/Applications/Windsurf.app",
                "/Applications/Windsurf - Next.app"
            ]
        case .zed:
            [
                "/Applications/Zed.app",
                "/Applications/Zed Preview.app"
            ]
        }
    }

    var applicationURL: URL? {
        for bundleIdentifier in bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return url
            }
        }

        return fallbackApplicationPaths
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    var isInstalled: Bool {
        applicationURL != nil
    }
}

enum SessionActivityState {
    case live
    case recent
    case idle

    init(lastUpdated: Date, now: Date = Date()) {
        let age = now.timeIntervalSince(lastUpdated)

        switch age {
        case ..<120:
            self = .live
        case ..<1800:
            self = .recent
        default:
            self = .idle
        }
    }

    var label: String {
        switch self {
        case .live: "Live"
        case .recent: "Recent"
        case .idle: "Idle"
        }
    }

    var tint: Color {
        switch self {
        case .live: .green
        case .recent: .orange
        case .idle: .secondary
        }
    }
}

@MainActor
final class OpenCodeController: ObservableObject {
    static let shared = OpenCodeController()

    @Published var pendingDeletionSession: RecentSession?
    @Published var actionError: String?
    @Published var isDeletingSession = false

    private init() {}

    func continueSession(_ session: RecentSession) {
        launchTerminal(in: session.directory, command: "opencode --session \(shellQuote(session.id))")
    }

    func continueLatestSession(for project: ProjectStats) {
        if let sessionID = project.latestSessionID, !sessionID.isEmpty {
            launchTerminal(in: project.path, command: "opencode --session \(shellQuote(sessionID))")
        } else {
            startNewSession(in: project)
        }
    }

    func startNewSession(in project: ProjectStats) {
        launchTerminal(in: project.path, command: "opencode")
    }

    func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInTerminal(_ path: String) {
        launchTerminal(in: path, command: nil)
    }

    func openProject(_ path: String, in app: ProjectOpenApp) {
        guard let applicationURL = app.applicationURL else {
            actionError = "\(app.displayName) is not installed."
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else { return }

            DispatchQueue.main.async {
                self?.actionError = error.localizedDescription
            }
        }
    }

    func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func requestDelete(_ session: RecentSession) {
        pendingDeletionSession = session
    }

    func confirmDeletePendingSession(onSuccess: @escaping () -> Void) {
        guard let session = pendingDeletionSession else { return }
        pendingDeletionSession = nil
        deleteSession(session, onSuccess: onSuccess)
    }

    private func deleteSession(_ session: RecentSession, onSuccess: @escaping () -> Void) {
        isDeletingSession = true

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "opencode session delete \(shellQuote(session.id))"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.terminationHandler = { [weak self] process in
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                self?.isDeletingSession = false

                guard process.terminationStatus == 0 else {
                    self?.actionError = error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? output.trimmingCharacters(in: .whitespacesAndNewlines)
                        : error.trimmingCharacters(in: .whitespacesAndNewlines)
                    return
                }

                onSuccess()
            }
        }

        do {
            try process.run()
        } catch {
            isDeletingSession = false
            actionError = error.localizedDescription
        }
    }

    private func launchTerminal(in directory: String, command: String?) {
        let terminal = PreferredTerminal.current

        guard terminal.isInstalled else {
            actionError = "\(terminal.displayName) is not installed."
            return
        }

        let shellCommand = if let command {
            "cd \(shellQuote(directory)) && \(command)"
        } else {
            "cd \(shellQuote(directory))"
        }

        let script: [String]
        switch terminal {
        case .terminal:
            script = terminalAppleScript(shellCommand: shellCommand)
        case .iTerm2:
            script = iTermAppleScript(shellCommand: shellCommand)
        case .ghostty:
            script = ghosttyAppleScript(directory: directory, command: command)
        case .cmux:
            script = cmuxAppleScript(
                shellCommand: shellCommand,
                bundleIdentifier: terminal.installedBundleIdentifier ?? terminal.bundleIdentifier
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = script.flatMap { ["-e", $0] }

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private func terminalAppleScript(shellCommand: String) -> [String] {
        [
            "tell application \"Terminal\"",
            "activate",
            "do script \(appleScriptQuote(shellCommand))",
            "end tell"
        ]
    }

    private func iTermAppleScript(shellCommand: String) -> [String] {
        let iTermCommand = "/bin/zsh -lc \(shellQuote(shellCommand))"
        return [
            "tell application \"iTerm2\"",
            "activate",
            "create window with default profile command \(appleScriptQuote(iTermCommand))",
            "end tell"
        ]
    }

    private func ghosttyAppleScript(directory: String, command: String?) -> [String] {
        var script = [
            "tell application \"Ghostty\"",
            "activate",
            "set cfg to new surface configuration",
            "set initial working directory of cfg to \(appleScriptQuote(directory))",
            "set win to new window with configuration cfg"
        ]

        if let command {
            script.append("set term to focused terminal of selected tab of win")
            script.append("input text \(appleScriptQuote(command)) to term")
            script.append("send key \"enter\" to term")
        }

        script.append("end tell")
        return script
    }

    private func cmuxAppleScript(shellCommand: String, bundleIdentifier: String) -> [String] {
        [
            "tell application id \(appleScriptQuote(bundleIdentifier))",
            "activate",
            "set win to new window",
            "set term to focused terminal of selected tab of win",
            "input text \(appleScriptQuote(shellCommand)) to term",
            "input text (ASCII character 13) to term",
            "end tell"
        ]
    }

    private func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
