import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
}

// MARK: - JSON Export Payload

private struct ExportPayload: Encodable {
    let exportedAt: String
    let summary: Summary
    let projects: [Project]
    let modelUsage: [ModelEntry]
    let toolUsage: [ToolEntry]
    let recentSessions: [SessionEntry]

    struct Summary: Encodable {
        let totalCost: Double
        let sessions: Int
        let messages: Int
        let daysActive: Int
        let avgCostPerDay: Double
        let todayCost: Double
        let totalInputTokens: Int64
        let totalOutputTokens: Int64
        let totalReasoningTokens: Int64
        let totalCacheRead: Int64
        let totalCacheWrite: Int64
    }

    struct Project: Encodable {
        let id: String
        let name: String
        let path: String
        let sessions: Int
        let messages: Int
        let cost: Double
        let inputTokens: Int64
        let outputTokens: Int64
        let cacheRead: Int64
        let cacheWrite: Int64
    }

    struct ModelEntry: Encodable {
        let provider: String
        let model: String
        let count: Int
        let cost: Double
    }

    struct ToolEntry: Encodable {
        let name: String
        let count: Int
        let percentage: Double
    }

    struct SessionEntry: Encodable {
        let id: String
        let title: String
        let project: String
        let cost: Double
        let messages: Int
        let provider: String
        let model: String
        let lastUpdated: String
    }
}

struct ExportManager {

    static func exportSummary(stats: OpenCodeStats, sessions: [RecentSession]) -> String {
        let lines: [String] = [
            "OpenCode Stats Export — \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))",
            "",
            "SUMMARY",
            csvLine("Total Cost", Formatters.currency(stats.totalCost)),
            csvLine("Sessions", Formatters.number(stats.sessionCount)),
            csvLine("Messages", Formatters.number(stats.messageCount)),
            csvLine("Days Active", "\(stats.dayCount)"),
            csvLine("Avg Cost/Day", Formatters.currency(stats.avgCostPerDay)),
            csvLine("Today Cost", Formatters.currency(stats.todayCost)),
            "",
            "TOKEN BREAKDOWN",
            csvLine("Input", "\(stats.totalInputTokens)"),
            csvLine("Output", "\(stats.totalOutputTokens)"),
            csvLine("Reasoning", "\(stats.totalReasoningTokens)"),
            csvLine("Cache Read", "\(stats.totalCacheRead)"),
            csvLine("Cache Write", "\(stats.totalCacheWrite)"),
            "",
            "PROJECTS",
            csvLine("Name", "Sessions", "Messages", "Cost", "Input Tokens", "Output Tokens", "Cache Read", "Cache Write"),
        ]
        let projectLines = stats.projects.map { p in
            csvLine(p.name, "\(p.sessionCount)", "\(p.messageCount)", String(format: "%.4f", p.cost), "\(p.inputTokens)", "\(p.outputTokens)", "\(p.cacheRead)", "\(p.cacheWrite)")
        }
        let separatorLine = ["", "MODEL USAGE", csvLine("Provider", "Model", "Message Count", "Cost")]
        let modelLines = stats.modelUsage.map { m in
            csvLine(m.provider, m.model, "\(m.count)", String(format: "%.4f", m.cost))
        }
        let toolSep = ["", "TOOL USAGE", csvLine("Tool Name", "Count", "Percentage")]
        let toolLines = stats.toolUsage.map { t in
            csvLine(t.name, "\(t.count)", String(format: "%.1f", t.percentage) + "%")
        }
        let sessionSep = ["", "RECENT SESSIONS", csvLine("Title", "Project", "Cost", "Messages", "Provider", "Model", "Last Updated")]
        let sessionLines = sessions.map { s in
            csvLine(s.title, s.projectName, String(format: "%.4f", s.cost), "\(s.messageCount)", s.provider, s.model, Formatters.relative(s.lastUpdated))
        }
        return (lines + projectLines + separatorLine + modelLines + toolSep + toolLines + sessionSep + sessionLines).joined(separator: "\n")
    }

    private static func csvLine(_ fields: String...) -> String {
        fields.map { field in
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            return field
        }.joined(separator: ",")
    }

    static func exportJSON(stats: OpenCodeStats, sessions: [RecentSession]) -> String {
        let df = ISO8601DateFormatter()

        let payload = ExportPayload(
            exportedAt: df.string(from: Date()),
            summary: .init(
                totalCost: stats.totalCost,
                sessions: stats.sessionCount,
                messages: stats.messageCount,
                daysActive: stats.dayCount,
                avgCostPerDay: stats.avgCostPerDay,
                todayCost: stats.todayCost,
                totalInputTokens: stats.totalInputTokens,
                totalOutputTokens: stats.totalOutputTokens,
                totalReasoningTokens: stats.totalReasoningTokens,
                totalCacheRead: stats.totalCacheRead,
                totalCacheWrite: stats.totalCacheWrite
            ),
            projects: stats.projects.map { p in
                .init(
                    id: p.id, name: p.name, path: p.path,
                    sessions: p.sessionCount, messages: p.messageCount,
                    cost: p.cost, inputTokens: p.inputTokens,
                    outputTokens: p.outputTokens, cacheRead: p.cacheRead,
                    cacheWrite: p.cacheWrite
                )
            },
            modelUsage: stats.modelUsage.map { m in
                .init(provider: m.provider, model: m.model, count: m.count, cost: m.cost)
            },
            toolUsage: stats.toolUsage.map { t in
                .init(name: t.name, count: t.count, percentage: t.percentage)
            },
            recentSessions: sessions.map { s in
                .init(
                    id: s.id, title: s.title, project: s.projectName,
                    cost: s.cost, messages: s.messageCount,
                    provider: s.provider, model: s.model,
                    lastUpdated: df.string(from: s.lastUpdated)
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func saveToFile(content: String, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .json]
        panel.nameFieldStringValue = "opencode-stats-export.\(format.rawValue.lowercased())"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            print("Export failed: \(error)")
        }
    }


}
