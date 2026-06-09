import XCTest
@testable import OpenCode_Stats

final class ExportManagerTests: XCTestCase {

    private let sampleStats = OpenCodeStats(
        sessionCount: 47,
        messageCount: 1823,
        dayCount: 12,
        totalCost: 152.34,
        avgCostPerDay: 12.695,
        totalInputTokens: 1_500_000,
        totalOutputTokens: 320_000,
        totalCacheRead: 200_000,
        totalCacheWrite: 50_000,
        totalReasoningTokens: 75_000,
        toolUsage: [
            ToolUsageItem(name: "read", count: 500, percentage: 55.5),
            ToolUsageItem(name: "edit", count: 300, percentage: 33.3),
            ToolUsageItem(name: "search", count: 100, percentage: 11.1)
        ],
        modelUsage: [
            ModelUsageItem(provider: "openai", model: "gpt-4", count: 100, cost: 120.00, percentage: 66.7),
            ModelUsageItem(provider: "anthropic", model: "claude-3", count: 50, cost: 32.34, percentage: 33.3)
        ],
        projects: [
            ProjectStats(id: "proj-1", name: "MyApp", path: "/Users/user/MyApp",
                         sessionCount: 20, messageCount: 800, cost: 80.00,
                         inputTokens: 800_000, outputTokens: 160_000,
                         cacheRead: 100_000, cacheWrite: 25_000,
                         latestSessionID: "sess-1",
                         latestSessionTitle: "Fix Login Bug",
                         latestSessionUpdatedAt: Date().addingTimeInterval(-3600)),
            ProjectStats(id: "proj-2", name: "Backend", path: "/Users/user/Backend",
                         sessionCount: 27, messageCount: 1023, cost: 72.34,
                         inputTokens: 700_000, outputTokens: 160_000,
                         cacheRead: 100_000, cacheWrite: 25_000,
                         latestSessionID: "sess-2",
                         latestSessionTitle: "Add API Route",
                         latestSessionUpdatedAt: Date().addingTimeInterval(-7200))
        ],
        todayCost: 5.20
    )

    private let sampleSessions: [RecentSession] = [
        RecentSession(id: "sess-1", title: "Fix Login Bug", projectName: "MyApp",
                      directory: "/Users/user/MyApp", slug: "fix-login",
                      cost: 15.50, messageCount: 120,
                      lastUpdated: Date().addingTimeInterval(-3600),
                      provider: "openai", model: "gpt-4"),
        RecentSession(id: "sess-2", title: "Add API Route", projectName: "Backend",
                      directory: "/Users/user/Backend", slug: "add-api",
                      cost: 8.25, messageCount: 65,
                      lastUpdated: Date().addingTimeInterval(-7200),
                      provider: "anthropic", model: "claude-3")
    ]

    // MARK: - CSV Export

    func test_exportSummary_containsExpectedSections() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("OpenCode Stats Export"))
        XCTAssertTrue(csv.contains("SUMMARY"))
        XCTAssertTrue(csv.contains("TOKEN BREAKDOWN"))
        XCTAssertTrue(csv.contains("PROJECTS"))
        XCTAssertTrue(csv.contains("MODEL USAGE"))
        XCTAssertTrue(csv.contains("TOOL USAGE"))
        XCTAssertTrue(csv.contains("RECENT SESSIONS"))
    }

    func test_exportSummary_containsStatsValues() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("Total Cost,$152.34"))
        XCTAssertTrue(csv.contains("Sessions,47"))
        XCTAssertTrue(csv.contains("Messages"))
        XCTAssertTrue(csv.contains("1,823"))
        XCTAssertTrue(csv.contains("Days Active,12"))
    }

    func test_exportSummary_containsProjectData() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("MyApp"))
        XCTAssertTrue(csv.contains("Backend"))
    }

    func test_exportSummary_containsModelData() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("gpt-4"))
        XCTAssertTrue(csv.contains("claude-3"))
    }

    func test_exportSummary_containsToolData() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("read"))
        XCTAssertTrue(csv.contains("edit"))
        XCTAssertTrue(csv.contains("search"))
    }

    func test_exportSummary_containsSessionData() {
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(csv.contains("Fix Login Bug"))
        XCTAssertTrue(csv.contains("Add API Route"))
    }

    func test_exportSummary_handlesCommaInField() {
        let awkwardSession = RecentSession(id: "sess-3", title: "Bug, Fix", projectName: "MyApp",
                                           directory: "/tmp", slug: "bug-fix",
                                           cost: 5.00, messageCount: 10,
                                           lastUpdated: Date(),
                                           provider: "openai", model: "gpt-4")
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: [awkwardSession])
        XCTAssertTrue(csv.contains("\"Bug, Fix\""))
    }

    func test_exportSummary_handlesQuoteInField() {
        let awkwardSession = RecentSession(id: "sess-4", title: "Bug \"Critical\"", projectName: "MyApp",
                                           directory: "/tmp", slug: "bug-critical",
                                           cost: 5.00, messageCount: 10,
                                           lastUpdated: Date(),
                                           provider: "openai", model: "gpt-4")
        let csv = ExportManager.exportSummary(stats: sampleStats, sessions: [awkwardSession])
        XCTAssertTrue(csv.contains("Bug \"\"Critical\"\""))
    }

    // MARK: - JSON Export

    func test_exportJSON_containsExpectedKeys() {
        let json = ExportManager.exportJSON(stats: sampleStats, sessions: sampleSessions)
        XCTAssertTrue(json.contains("\"exportedAt\""))
        XCTAssertTrue(json.contains("\"summary\""))
        XCTAssertTrue(json.contains("\"projects\""))
        XCTAssertTrue(json.contains("\"modelUsage\""))
        XCTAssertTrue(json.contains("\"toolUsage\""))
        XCTAssertTrue(json.contains("\"recentSessions\""))
    }

    func test_exportJSON_containsStatsValues() throws {
        let json = ExportManager.exportJSON(stats: sampleStats, sessions: sampleSessions)
        let data = Data(json.utf8)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let summary = try XCTUnwrap(parsed["summary"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(summary["totalCost"] as? Double), 152.34, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary["sessions"] as? Int), 47)
        XCTAssertEqual(try XCTUnwrap(summary["messages"] as? Int), 1823)
        XCTAssertEqual(try XCTUnwrap(summary["todayCost"] as? Double), 5.2, accuracy: 0.001)
    }

    func test_exportJSON_validJSON() {
        let json = ExportManager.exportJSON(stats: sampleStats, sessions: sampleSessions)
        let data = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["summary"])
        XCTAssertNotNil(parsed?["projects"])
        XCTAssertNotNil(parsed?["modelUsage"])
        XCTAssertNotNil(parsed?["toolUsage"])
        XCTAssertNotNil(parsed?["recentSessions"])
    }

    func test_exportJSON_projectData() throws {
        let json = ExportManager.exportJSON(stats: sampleStats, sessions: sampleSessions)
        let data = Data(json.utf8)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let projects = try XCTUnwrap(parsed["projects"] as? [[String: Any]])
        XCTAssertTrue(projects.contains(where: { $0["name"] as? String == "MyApp" }))
        XCTAssertTrue(projects.contains(where: { $0["name"] as? String == "Backend" }))
    }

    func test_exportJSON_handlesSpecialChars() {
        let specialSession = RecentSession(id: "sess-5", title: "Line\nBreak & \"Quote\"",
                                           projectName: "Test\"App", directory: "/tmp",
                                           slug: "special", cost: 1.0, messageCount: 1,
                                           lastUpdated: Date(),
                                           provider: "openai", model: "gpt-4")
        let json = ExportManager.exportJSON(stats: sampleStats, sessions: [specialSession])
        let data = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(parsed)
    }

    // MARK: - Empty data edge cases

    func test_exportSummary_emptyData() {
        let empty = OpenCodeStats()
        let csv = ExportManager.exportSummary(stats: empty, sessions: [])
        XCTAssertTrue(csv.contains("Total Cost,$0.00"))
        XCTAssertTrue(csv.contains("Sessions,0"))
    }

    func test_exportJSON_emptyData_validJSON() {
        let empty = OpenCodeStats()
        let json = ExportManager.exportJSON(stats: empty, sessions: [])
        let data = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(parsed)
    }
}
