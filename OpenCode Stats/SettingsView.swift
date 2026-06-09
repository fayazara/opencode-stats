//
//  SettingsView.swift
//  OpenCode Stats
//
//  Created by Codex on 10/04/26.
//

import AppKit
import SwiftUI

private enum OpenCodeSettingsTab: String, CaseIterable {
    case general
    case actions
    case about

    var title: String {
        switch self {
        case .general: "General"
        case .actions: "Actions"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .actions: "terminal"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: OpenCodeSettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .actions:
                    ActionsSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 520, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(OpenCodeSettingsTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func tabButton(for tab: OpenCodeSettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                    .frame(width: 28, height: 22)

                Text(tab.title)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
            .frame(width: 68, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(OpenCodePreferenceKey.preferredTerminal) private var preferredTerminalRawValue = PreferredTerminal.terminal.rawValue

    private var selectedTerminal: PreferredTerminal {
        PreferredTerminal(rawValue: preferredTerminalRawValue) ?? .terminal
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsFormRow("Preferred terminal:") {
                Picker("Preferred terminal", selection: $preferredTerminalRawValue) {
                    ForEach(PreferredTerminal.allCases) { terminal in
                        Text(terminal.displayName).tag(terminal.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            settingsFormRow("") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedTerminal.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TerminalInstallStatusView(terminal: selectedTerminal)
                }
            }

            settingsSectionDivider()

            settingsFormRow("Used for:") {
                VStack(alignment: .leading, spacing: 7) {
                    SettingsInlineLabel(icon: "play.circle", text: "Continue a saved session")
                    SettingsInlineLabel(icon: "folder.badge.gearshape", text: "Continue the latest project session")
                    SettingsInlineLabel(icon: "plus.square.on.square", text: "Start a fresh OpenCode session")
                    SettingsInlineLabel(icon: "terminal", text: "Open a project directory in your terminal")
                    SettingsInlineLabel(icon: "macwindow", text: "Open a project directory in Cursor, VS Code, Windsurf, or Zed")
                }
            }

            settingsSectionDivider()

            settingsFormRow("Behavior:") {
                Text("OpenCode Stats opens the selected terminal in the project directory, then runs the relevant OpenCode command. If the terminal app is missing, the action fails visibly instead of guessing another app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsSectionDivider()

            BudgetSettingsView()

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }
}

private struct BudgetSettingsView: View {
    @AppStorage("budgetAlertsEnabled") private var enabled = false
    @AppStorage("dailyBudget") private var dailyBudget: Double = 0
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            settingsFormRow("Budget alerts:") {
                Toggle(isOn: $enabled) {
                    Text("Enable cost budget alerts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()
            }

            if enabled {
                settingsFormRow("Daily budget:") {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        TextField("0.00", value: $dailyBudget, format: .number.precision(.fractionLength(2)))
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Text("(menu bar turns orange when exceeded)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                    }
                }

                settingsFormRow("Monthly budget:") {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        TextField("0.00", value: $monthlyBudget, format: .number.precision(.fractionLength(2)))
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Text("(reset each calendar month)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize()
                    }
                }

            }
        }
        .onChange(of: enabled) { _ in notifyRecheck() }
        .onChange(of: dailyBudget) { _ in notifyRecheck() }
        .onChange(of: monthlyBudget) { _ in notifyRecheck() }
    }

    private func notifyRecheck() {
        NotificationCenter.default.post(name: .budgetSettingsChanged, object: nil)
    }
}

private struct ActionsSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            settingsFormRow("Continue session:") {
                CommandPreview("opencode --session <session-id>")
            }

            settingsFormRow("Latest session:") {
                CommandPreview("opencode --session <latest-session-id>")
            }

            settingsFormRow("New session:") {
                CommandPreview("opencode")
            }

            settingsFormRow("Open project:") {
                CommandPreview("cd <project-path>")
            }

            settingsSectionDivider()

            settingsFormRow("Working directory:") {
                Text("Session actions use the session directory. Project actions use the project path shown in the Projects tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsFormRow("Command source:") {
                Text("The app does not proxy AI prompts or run OpenCode as a background agent. It only opens the local CLI where you can take over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }
}

private struct AboutSettingsView: View {
    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "v\(version) (\(build))"
    }()

    var body: some View {
        VStack(spacing: 12) {
            if let image = NSImage(named: "opencode-logo") ?? NSImage(named: "menubar-icon") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }

            Text("OpenCode Stats")
                .font(.title2.bold())

            Text(appVersion)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Stats and lightweight session management for OpenCode.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .padding(.horizontal, 56)
                .padding(.top, 4)

            HStack(spacing: 12) {
                Button("GitHub") {
                    openURL("https://github.com/fayazara/opencode-stats")
                }
                .controlSize(.small)

                Button("OpenCode Docs") {
                    openURL("https://opencode.ai/docs/")
                }
                .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct TerminalInstallStatusView: View {
    let terminal: PreferredTerminal

    var body: some View {
        Label {
            Text(terminal.isInstalled ? "\(terminal.displayName) is installed." : "\(terminal.displayName) is not installed on this Mac.")
        } icon: {
            Image(systemName: terminal.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(terminal.isInstalled ? .green : .orange)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct SettingsInlineLabel: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct CommandPreview: View {
    let command: String

    init(_ command: String) {
        self.command = command
    }

    var body: some View {
        Text(command)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

private let settingsFormLabelWidth: CGFloat = 140

private func settingsFormRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(label)
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .frame(width: settingsFormLabelWidth, alignment: .trailing)

        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 4)
}

private func settingsSectionDivider() -> some View {
    Divider()
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
}

#Preview {
    SettingsView()
}
