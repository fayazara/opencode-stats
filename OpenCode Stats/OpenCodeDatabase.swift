//
//  OpenCodeDatabase.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import Foundation
import Combine
import SQLite3

// MARK: - Data Models

struct OpenCodeStats {
    var sessionCount: Int = 0
    var messageCount: Int = 0
    var dayCount: Int = 0
    var totalCost: Double = 0
    var avgCostPerDay: Double = 0
    var totalInputTokens: Int64 = 0
    var totalOutputTokens: Int64 = 0
    var totalCacheRead: Int64 = 0
    var totalCacheWrite: Int64 = 0
    var totalReasoningTokens: Int64 = 0
    var avgTokensPerSession: Double = 0
    var medianTokensPerSession: Double = 0
    var toolUsage: [ToolUsageItem] = []
    var modelUsage: [ModelUsageItem] = []
    var projects: [ProjectStats] = []
    var mcpServers: [MCPServer] = []
    var dailyCosts: [DailyCost] = []
    var recentSessions: [RecentSession] = []
    var todayCost: Double = 0
    var firstSessionDate: Date?
    var lastSessionDate: Date?
}

struct DailyCost: Identifiable {
    let id = UUID()
    let date: String // yyyy-MM-dd
    let cost: Double
    let messageCount: Int
}

struct RecentSession: Identifiable {
    let id: String
    let title: String
    let projectName: String
    let cost: Double
    let messageCount: Int
    let date: Date
    let provider: String
    let model: String
}

struct MCPServer: Identifiable {
    let id = UUID()
    let name: String
    let type: MCPType
    let detail: String // URL for remote, command for local

    enum MCPType: String {
        case local = "Local"
        case remote = "Remote"
    }
}

struct ToolUsageItem: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let percentage: Double
}

struct ModelUsageItem: Identifiable {
    let id = UUID()
    let provider: String
    let model: String
    let count: Int
    let cost: Double
    let percentage: Double
}

struct ProjectStats: Identifiable {
    let id: String
    let name: String
    let path: String
    let sessionCount: Int
    let messageCount: Int
    let cost: Double
    let inputTokens: Int64
    let outputTokens: Int64
    let cacheRead: Int64
    let cacheWrite: Int64
}

// MARK: - Database Service

class OpenCodeDatabase: ObservableObject {
    @Published var stats = OpenCodeStats()
    @Published var isLoading = false
    @Published var error: String?
    @Published var daysFilter: Int? = nil // nil = all time

    private var db: OpaquePointer?

    static let shared = OpenCodeDatabase()

    var dbPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.local/share/opencode/opencode.db"
    }

    var dbExists: Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }

    static var isDemoMode: Bool {
        CommandLine.arguments.contains("-DEMO_MODE")
    }

    init() {}

    func refresh() {
        isLoading = true
        error = nil

        if Self.isDemoMode {
            DispatchQueue.main.async {
                self.stats = Self.mockStats()
                self.isLoading = false
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let result = try self.loadStats()
                DispatchQueue.main.async {
                    self.stats = result
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadStats() throws -> OpenCodeStats {
        guard dbExists else {
            throw DatabaseError.notFound
        }

        var db: OpaquePointer?
        // Open in read-only mode with WAL support
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            throw DatabaseError.cannotOpen
        }
        defer { sqlite3_close(db) }

        var stats = OpenCodeStats()

        let dateFilter = daysFilter.map { days -> Int64 in
            let cutoff = Date().addingTimeInterval(Double(-days * 86400))
            return Int64(cutoff.timeIntervalSince1970 * 1000)
        }

        // Session count and date range
        let sessionQuery: String
        if let cutoff = dateFilter {
            sessionQuery = "SELECT COUNT(*), MIN(time_created), MAX(time_created) FROM session WHERE parent_id IS NULL AND time_created >= \(cutoff)"
        } else {
            sessionQuery = "SELECT COUNT(*), MIN(time_created), MAX(time_created) FROM session WHERE parent_id IS NULL"
        }
        if let row = try querySingle(db: db, sql: sessionQuery) {
            stats.sessionCount = row[0] as? Int ?? 0
            if let minTs = row[1] as? Int64, let maxTs = row[2] as? Int64 {
                stats.firstSessionDate = Date(timeIntervalSince1970: Double(minTs) / 1000)
                stats.lastSessionDate = Date(timeIntervalSince1970: Double(maxTs) / 1000)
                let daySpan = max(1, Int(ceil(Double(maxTs - minTs) / 86_400_000.0)) + 1)
                stats.dayCount = daySpan
            }
        }

        // Message count + cost + tokens from assistant messages
        let msgQuery: String
        if let cutoff = dateFilter {
            msgQuery = """
                SELECT
                    COUNT(*),
                    COALESCE(SUM(json_extract(m.data, '$.cost')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.input')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.output')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.cache.read')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.cache.write')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.reasoning')), 0)
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
                  AND s.time_created >= \(cutoff)
            """
        } else {
            msgQuery = """
                SELECT
                    COUNT(*),
                    COALESCE(SUM(json_extract(m.data, '$.cost')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.input')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.output')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.cache.read')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.cache.write')), 0),
                    COALESCE(SUM(json_extract(m.data, '$.tokens.reasoning')), 0)
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
            """
        }
        if let row = try querySingle(db: db, sql: msgQuery) {
            stats.messageCount = row[0] as? Int ?? 0
            stats.totalCost = row[1] as? Double ?? 0
            stats.totalInputTokens = (row[2] as? Int64) ?? 0
            stats.totalOutputTokens = (row[3] as? Int64) ?? 0
            stats.totalCacheRead = (row[4] as? Int64) ?? 0
            stats.totalCacheWrite = (row[5] as? Int64) ?? 0
            stats.totalReasoningTokens = (row[6] as? Int64) ?? 0
        }

        // Total message count (both user + assistant)
        let totalMsgQuery: String
        if let cutoff = dateFilter {
            totalMsgQuery = "SELECT COUNT(*) FROM message m JOIN session s ON s.id = m.session_id WHERE s.parent_id IS NULL AND s.time_created >= \(cutoff)"
        } else {
            totalMsgQuery = "SELECT COUNT(*) FROM message m JOIN session s ON s.id = m.session_id WHERE s.parent_id IS NULL"
        }
        if let row = try querySingle(db: db, sql: totalMsgQuery) {
            stats.messageCount = row[0] as? Int ?? 0
        }

        // Avg cost per day
        if stats.dayCount > 0 {
            stats.avgCostPerDay = stats.totalCost / Double(stats.dayCount)
        }

        // Tokens per session (avg + median)
        let tokensPerSessionQuery: String
        if let cutoff = dateFilter {
            tokensPerSessionQuery = """
                SELECT COALESCE(SUM(
                    json_extract(m.data, '$.tokens.input') +
                    json_extract(m.data, '$.tokens.output') +
                    json_extract(m.data, '$.tokens.cache.read') +
                    json_extract(m.data, '$.tokens.cache.write')
                ), 0) as total_tokens
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
                  AND s.time_created >= \(cutoff)
                GROUP BY m.session_id
                ORDER BY total_tokens
            """
        } else {
            tokensPerSessionQuery = """
                SELECT COALESCE(SUM(
                    json_extract(m.data, '$.tokens.input') +
                    json_extract(m.data, '$.tokens.output') +
                    json_extract(m.data, '$.tokens.cache.read') +
                    json_extract(m.data, '$.tokens.cache.write')
                ), 0) as total_tokens
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
                GROUP BY m.session_id
                ORDER BY total_tokens
            """
        }
        let sessionTokens = try queryColumn(db: db, sql: tokensPerSessionQuery)
        if !sessionTokens.isEmpty {
            let total = sessionTokens.reduce(0.0) { $0 + $1 }
            stats.avgTokensPerSession = total / Double(stats.sessionCount > 0 ? stats.sessionCount : 1)
            let mid = sessionTokens.count / 2
            if sessionTokens.count % 2 == 0 && sessionTokens.count > 1 {
                stats.medianTokensPerSession = (sessionTokens[mid - 1] + sessionTokens[mid]) / 2
            } else {
                stats.medianTokensPerSession = sessionTokens[mid]
            }
        }

        // Tool usage
        let toolQuery: String
        if let cutoff = dateFilter {
            toolQuery = """
                SELECT json_extract(p.data, '$.tool') as tool_name, COUNT(*) as cnt
                FROM part p
                JOIN session s ON s.id = p.session_id
                WHERE json_extract(p.data, '$.type') = 'tool'
                  AND s.parent_id IS NULL
                  AND s.time_created >= \(cutoff)
                GROUP BY tool_name
                ORDER BY cnt DESC
            """
        } else {
            toolQuery = """
                SELECT json_extract(p.data, '$.tool') as tool_name, COUNT(*) as cnt
                FROM part p
                JOIN session s ON s.id = p.session_id
                WHERE json_extract(p.data, '$.type') = 'tool'
                  AND s.parent_id IS NULL
                GROUP BY tool_name
                ORDER BY cnt DESC
            """
        }
        let toolRows = try queryRows(db: db, sql: toolQuery)
        let totalTools = toolRows.reduce(0) { $0 + ($1[1] as? Int ?? 0) }
        stats.toolUsage = toolRows.map { row in
            let name = row[0] as? String ?? "unknown"
            let count = row[1] as? Int ?? 0
            let pct = totalTools > 0 ? Double(count) / Double(totalTools) * 100 : 0
            return ToolUsageItem(name: name, count: count, percentage: pct)
        }

        // Model usage
        let modelQuery: String
        if let cutoff = dateFilter {
            modelQuery = """
                SELECT
                    json_extract(m.data, '$.providerID') as provider,
                    json_extract(m.data, '$.modelID') as model,
                    COUNT(*) as cnt,
                    COALESCE(SUM(json_extract(m.data, '$.cost')), 0) as cost
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
                  AND s.time_created >= \(cutoff)
                GROUP BY provider, model
                ORDER BY cost DESC
            """
        } else {
            modelQuery = """
                SELECT
                    json_extract(m.data, '$.providerID') as provider,
                    json_extract(m.data, '$.modelID') as model,
                    COUNT(*) as cnt,
                    COALESCE(SUM(json_extract(m.data, '$.cost')), 0) as cost
                FROM message m
                JOIN session s ON s.id = m.session_id
                WHERE json_extract(m.data, '$.role') = 'assistant'
                  AND s.parent_id IS NULL
                GROUP BY provider, model
                ORDER BY cost DESC
            """
        }
        let modelRows = try queryRows(db: db, sql: modelQuery)
        let totalModelMsgs = modelRows.reduce(0) { $0 + ($1[2] as? Int ?? 0) }
        stats.modelUsage = modelRows.map { row in
            let provider = row[0] as? String ?? "unknown"
            let model = row[1] as? String ?? "unknown"
            let count = row[2] as? Int ?? 0
            let cost = row[3] as? Double ?? 0
            let pct = totalModelMsgs > 0 ? Double(count) / Double(totalModelMsgs) * 100 : 0
            return ModelUsageItem(provider: provider, model: model, count: count, cost: cost, percentage: pct)
        }

        // Project breakdown
        let projectQuery: String
        if let cutoff = dateFilter {
            projectQuery = """
                SELECT
                    p.id,
                    p.worktree,
                    p.name,
                    COUNT(DISTINCT s.id) as session_count,
                    COUNT(m.id) as msg_count,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.cost') ELSE 0 END), 0) as cost,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.input') ELSE 0 END), 0) as input_tokens,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.output') ELSE 0 END), 0) as output_tokens,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.cache.read') ELSE 0 END), 0) as cache_read,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.cache.write') ELSE 0 END), 0) as cache_write
                FROM project p
                JOIN session s ON s.project_id = p.id AND s.parent_id IS NULL
                LEFT JOIN message m ON m.session_id = s.id
                WHERE s.time_created >= \(cutoff)
                GROUP BY p.id
                HAVING session_count > 0
                ORDER BY cost DESC
            """
        } else {
            projectQuery = """
                SELECT
                    p.id,
                    p.worktree,
                    p.name,
                    COUNT(DISTINCT s.id) as session_count,
                    COUNT(m.id) as msg_count,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.cost') ELSE 0 END), 0) as cost,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.input') ELSE 0 END), 0) as input_tokens,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.output') ELSE 0 END), 0) as output_tokens,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.cache.read') ELSE 0 END), 0) as cache_read,
                    COALESCE(SUM(CASE WHEN json_extract(m.data, '$.role') = 'assistant' THEN json_extract(m.data, '$.tokens.cache.write') ELSE 0 END), 0) as cache_write
                FROM project p
                JOIN session s ON s.project_id = p.id AND s.parent_id IS NULL
                LEFT JOIN message m ON m.session_id = s.id
                GROUP BY p.id
                HAVING session_count > 0
                ORDER BY cost DESC
            """
        }
        let projectRows = try queryRows(db: db, sql: projectQuery)
        stats.projects = projectRows.map { row in
            let worktree = row[1] as? String ?? ""
            let name = (row[2] as? String) ?? URL(fileURLWithPath: worktree).lastPathComponent
            return ProjectStats(
                id: row[0] as? String ?? "",
                name: name,
                path: worktree,
                sessionCount: row[3] as? Int ?? 0,
                messageCount: row[4] as? Int ?? 0,
                cost: row[5] as? Double ?? 0,
                inputTokens: (row[6] as? Int64) ?? 0,
                outputTokens: (row[7] as? Int64) ?? 0,
                cacheRead: (row[8] as? Int64) ?? 0,
                cacheWrite: (row[9] as? Int64) ?? 0
            )
        }

        // MCP servers from config
        stats.mcpServers = Self.loadMCPServers()

        // Daily costs (last 30 days)
        let dailyCostQuery = """
            SELECT date(m.time_created/1000, 'unixepoch', 'localtime') as day,
                   COALESCE(SUM(json_extract(m.data, '$.cost')), 0) as cost,
                   COUNT(*) as msgs
            FROM message m
            JOIN session s ON s.id = m.session_id
            WHERE json_extract(m.data, '$.role') = 'assistant'
              AND s.parent_id IS NULL
              AND m.time_created >= \(Int64(Date().addingTimeInterval(-30 * 86400).timeIntervalSince1970 * 1000))
            GROUP BY day ORDER BY day
        """
        let dailyRows = try queryRows(db: db, sql: dailyCostQuery)
        stats.dailyCosts = dailyRows.map { row in
            DailyCost(
                date: row[0] as? String ?? "",
                cost: row[1] as? Double ?? 0,
                messageCount: row[2] as? Int ?? 0
            )
        }

        // Today's cost
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayMs = Int64(todayStart.timeIntervalSince1970 * 1000)
        let todayQuery = """
            SELECT COALESCE(SUM(json_extract(m.data, '$.cost')), 0)
            FROM message m
            JOIN session s ON s.id = m.session_id
            WHERE json_extract(m.data, '$.role') = 'assistant'
              AND s.parent_id IS NULL
              AND m.time_created >= \(todayMs)
        """
        if let row = try querySingle(db: db, sql: todayQuery) {
            stats.todayCost = row[0] as? Double ?? 0
        }

        // Recent sessions (last 15)
        let recentQuery = """
            SELECT s.id, s.title, p.worktree, p.name,
                   s.time_created,
                   COALESCE((SELECT SUM(json_extract(m.data, '$.cost'))
                             FROM message m
                             WHERE m.session_id = s.id
                               AND json_extract(m.data, '$.role') = 'assistant'), 0) as cost,
                   COALESCE((SELECT COUNT(*)
                             FROM message m
                             WHERE m.session_id = s.id), 0) as msg_count,
                   COALESCE((SELECT json_extract(m.data, '$.providerID')
                             FROM message m
                             WHERE m.session_id = s.id
                               AND json_extract(m.data, '$.role') = 'assistant'
                             ORDER BY m.time_created DESC LIMIT 1), '') as provider,
                   COALESCE((SELECT json_extract(m.data, '$.modelID')
                             FROM message m
                             WHERE m.session_id = s.id
                               AND json_extract(m.data, '$.role') = 'assistant'
                             ORDER BY m.time_created DESC LIMIT 1), '') as model
            FROM session s
            JOIN project p ON p.id = s.project_id
            WHERE s.parent_id IS NULL
            ORDER BY s.time_created DESC
            LIMIT 15
        """
        let recentRows = try queryRows(db: db, sql: recentQuery)
        stats.recentSessions = recentRows.map { row in
            let worktree = row[2] as? String ?? ""
            let projectName = (row[3] as? String) ?? URL(fileURLWithPath: worktree).lastPathComponent
            let ts = row[4] as? Int64 ?? (row[4] as? Int).map({ Int64($0) }) ?? 0
            return RecentSession(
                id: row[0] as? String ?? "",
                title: row[1] as? String ?? "Untitled",
                projectName: projectName,
                cost: row[5] as? Double ?? 0,
                messageCount: row[6] as? Int ?? 0,
                date: Date(timeIntervalSince1970: Double(ts) / 1000),
                provider: row[7] as? String ?? "",
                model: row[8] as? String ?? ""
            )
        }

        return stats
    }

    // MARK: - MCP Config

    private static func loadMCPServers() -> [MCPServer] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.config/opencode/opencode.json"

        guard FileManager.default.fileExists(atPath: configPath),
              let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcp = json["mcp"] as? [String: Any] else {
            return []
        }

        return mcp.compactMap { name, value in
            guard let config = value as? [String: Any],
                  let typeStr = config["type"] as? String else { return nil }

            let type: MCPServer.MCPType = typeStr == "remote" ? .remote : .local
            let detail: String
            if type == .remote {
                detail = config["url"] as? String ?? ""
            } else {
                let cmd = config["command"] as? [String] ?? []
                detail = cmd.joined(separator: " ")
            }

            return MCPServer(name: name, type: type, detail: detail)
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - SQLite Helpers

    private func querySingle(db: OpaquePointer?, sql: String) throws -> [Any]? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return extractRow(stmt: stmt)
    }

    private func queryRows(db: OpaquePointer?, sql: String) throws -> [[Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [[Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(extractRow(stmt: stmt))
        }
        return results
    }

    private func queryColumn(db: OpaquePointer?, sql: String) throws -> [Double] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        var results: [Double] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(sqlite3_column_double(stmt, 0))
        }
        return results
    }

    private func extractRow(stmt: OpaquePointer?) -> [Any] {
        let count = sqlite3_column_count(stmt)
        var row: [Any] = []
        for i in 0..<count {
            let type = sqlite3_column_type(stmt, i)
            switch type {
            case SQLITE_INTEGER:
                let val = sqlite3_column_int64(stmt, i)
                if val <= Int64(Int.max) && val >= Int64(Int.min) && val < 1_000_000_000 {
                    row.append(Int(val))
                } else {
                    row.append(val)
                }
            case SQLITE_FLOAT:
                row.append(sqlite3_column_double(stmt, i))
            case SQLITE_TEXT:
                let text = String(cString: sqlite3_column_text(stmt, i))
                row.append(text)
            case SQLITE_NULL:
                row.append(NSNull())
            default:
                row.append(NSNull())
            }
        }
        return row
    }

    // MARK: - Demo Mode Mock Data

    private static func mockStats() -> OpenCodeStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var daily: [DailyCost] = []
        for i in (0..<30).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let cost = Double.random(in: 2...35)
            daily.append(DailyCost(
                date: formatter.string(from: date),
                cost: cost,
                messageCount: Int.random(in: 10...120)
            ))
        }

        let projects = [
            ("acme-web", 82, 1240, 312.50),
            ("mobile-app", 45, 680, 189.20),
            ("api-service", 38, 520, 156.80),
            ("design-system", 24, 310, 98.40),
            ("docs-site", 18, 240, 72.10),
            ("cli-tools", 12, 160, 45.30),
            ("infra", 8, 95, 28.60),
        ].map { (name, sessions, msgs, cost) in
            ProjectStats(
                id: UUID().uuidString, name: name, path: "~/Developer/\(name)",
                sessionCount: sessions, messageCount: msgs, cost: cost,
                inputTokens: Int64.random(in: 1_000_000...10_000_000),
                outputTokens: Int64.random(in: 200_000...2_000_000),
                cacheRead: Int64.random(in: 5_000_000...50_000_000),
                cacheWrite: Int64.random(in: 500_000...5_000_000)
            )
        }

        let models = [
            ("anthropic", "claude-sonnet-4", 4200, 482.30),
            ("anthropic", "claude-opus-4", 1800, 312.10),
            ("openai", "gpt-4.1", 920, 86.40),
            ("google", "gemini-2.5-pro", 340, 24.80),
            ("anthropic", "claude-haiku-4", 280, 8.50),
        ].map { (provider, model, count, cost) in
            ModelUsageItem(provider: provider, model: model, count: count, cost: cost, percentage: 0)
        }

        let tools: [ToolUsageItem] = [
            ("read", 5420, 38.2), ("edit", 2810, 19.8), ("bash", 1950, 13.7),
            ("write", 1240, 8.7), ("todowrite", 1100, 7.7), ("glob", 620, 4.4),
            ("grep", 410, 2.9), ("webfetch", 280, 2.0), ("task", 190, 1.3), ("question", 130, 0.9),
        ].map { (name, count, pct) in
            ToolUsageItem(name: name, count: count, percentage: pct)
        }

        let sessions: [RecentSession] = [
            ("Implement user auth flow", "acme-web", 18.40, 42, -0.5),
            ("Fix pagination bug in API", "api-service", 6.20, 18, -2),
            ("Add dark mode support", "design-system", 12.80, 34, -5),
            ("Refactor database layer", "api-service", 22.50, 56, -8),
            ("Setup CI/CD pipeline", "infra", 8.90, 24, -12),
            ("Write component tests", "design-system", 5.40, 16, -18),
            ("Optimize image loading", "mobile-app", 14.30, 38, -24),
            ("Update API documentation", "docs-site", 3.80, 12, -30),
            ("Add search functionality", "acme-web", 16.70, 44, -36),
            ("Fix memory leak in cache", "api-service", 9.60, 28, -48),
        ].map { (title, project, cost, msgs, hoursAgo) in
            RecentSession(
                id: UUID().uuidString, title: title, projectName: project,
                cost: cost, messageCount: msgs,
                date: Date().addingTimeInterval(hoursAgo * 3600),
                provider: "anthropic", model: "claude-sonnet-4"
            )
        }

        let mcps = [
            MCPServer(name: "GitHub", type: .remote, detail: "https://api.githubcopilot.com/mcp"),
            MCPServer(name: "Postgres", type: .local, detail: "npx -y @modelcontextprotocol/server-postgres"),
            MCPServer(name: "Figma", type: .remote, detail: "https://mcp.figma.com"),
        ]

        return OpenCodeStats(
            sessionCount: 227,
            messageCount: 12840,
            dayCount: 94,
            totalCost: 902.90,
            avgCostPerDay: 9.60,
            totalInputTokens: 42_600_000,
            totalOutputTokens: 5_800_000,
            totalCacheRead: 890_000_000,
            totalCacheWrite: 58_200_000,
            totalReasoningTokens: 1_200_000,
            avgTokensPerSession: 2_400_000,
            medianTokensPerSession: 180_000,
            toolUsage: tools,
            modelUsage: models,
            projects: projects,
            mcpServers: mcps,
            dailyCosts: daily,
            recentSessions: sessions,
            todayCost: 14.20,
            firstSessionDate: Calendar.current.date(byAdding: .day, value: -94, to: Date()),
            lastSessionDate: Date()
        )
    }
}

enum DatabaseError: LocalizedError {
    case notFound
    case cannotOpen
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "OpenCode database not found at ~/.local/share/opencode/opencode.db"
        case .cannotOpen:
            return "Could not open the OpenCode database"
        case .queryFailed(let msg):
            return "Query failed: \(msg)"
        }
    }
}
