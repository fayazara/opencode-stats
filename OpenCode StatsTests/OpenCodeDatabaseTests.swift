import XCTest
import SQLite3
@testable import OpenCode_Stats

final class OpenCodeDatabaseTests: XCTestCase {

    private var sut: OpenCodeDatabase!
    private var db: OpaquePointer?
    private var dbPath: String!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("opencode.db").path

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            XCTFail("Failed to create test database")
            return
        }
        self.db = db
        createSchema()
    }

    override func tearDown() {
        if let db = db {
            sqlite3_close(db)
        }
        if let path = dbPath {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: path + "-wal")
            try? FileManager.default.removeItem(atPath: path + "-shm")
        }
        sut = nil
        super.tearDown()
    }

    // MARK: - Schema Helpers

    private func createSchema() {
        exec("""
            CREATE TABLE IF NOT EXISTS project (
                id TEXT PRIMARY KEY,
                name TEXT,
                worktree TEXT
            );
            CREATE TABLE IF NOT EXISTS session (
                id TEXT PRIMARY KEY,
                project_id TEXT,
                parent_id TEXT,
                title TEXT,
                slug TEXT,
                time_created INTEGER,
                time_updated INTEGER,
                FOREIGN KEY(project_id) REFERENCES project(id)
            );
            CREATE TABLE IF NOT EXISTS message (
                id TEXT PRIMARY KEY,
                session_id TEXT,
                time_created INTEGER,
                data TEXT,
                FOREIGN KEY(session_id) REFERENCES session(id)
            );
            CREATE TABLE IF NOT EXISTS part (
                id TEXT PRIMARY KEY,
                session_id TEXT,
                time_created INTEGER,
                data TEXT,
                FOREIGN KEY(session_id) REFERENCES session(id)
            );
        """)
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK, let err = errMsg {
            let msg = String(cString: err)
            sqlite3_free(errMsg)
            XCTFail("SQL error: \(msg) in: \(sql.prefix(120))")
            return false
        }
        return true
    }

    private func lastID() -> String { UUID().uuidString }

    private func ms(_ date: Date = Date()) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    // MARK: - SUT

    private func makeSUT() -> OpenCodeDatabase {
        let db = OpenCodeDatabase()
        db.overriddenDbPath = dbPath
        return db
    }

    // MARK: - Tests

    func test_emptyDatabase_returnsZeroStats() throws {
        sut = makeSUT()
        let stats = try sut.loadStats()
        XCTAssertEqual(stats.sessionCount, 0)
        XCTAssertEqual(stats.messageCount, 0)
        XCTAssertEqual(stats.totalCost, 0)
        XCTAssertEqual(stats.projects.count, 0)
        XCTAssertEqual(stats.modelUsage.count, 0)
        XCTAssertEqual(stats.toolUsage.count, 0)
    }

    func test_singleSession_correctlyAggregated() throws {
        let projectID = lastID()
        let sessionID = lastID()
        let now = Date()

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/Users/test/MyApp')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessionID)', '\(projectID)', NULL, 'Test Session', 'test-session', \(ms(now)), \(ms(now)))")
        exec("""
            INSERT INTO message (id, session_id, time_created, data) VALUES
            ('\(lastID())', '\(sessionID)', \(ms(now)), '{"role":"assistant","cost":1.50,"tokens":{"input":100,"output":50,"cache":{"read":20,"write":10},"reasoning":25},"providerID":"anthropic","modelID":"claude-sonnet-4"}'),
            ('\(lastID())', '\(sessionID)', \(ms(now)), '{"role":"user","cost":0,"tokens":{}}')
        """)

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.sessionCount, 1)
        XCTAssertEqual(stats.messageCount, 2)
        XCTAssertEqual(stats.totalCost, 1.50, accuracy: 0.001)
        XCTAssertEqual(stats.totalInputTokens, 100)
        XCTAssertEqual(stats.totalOutputTokens, 50)
        XCTAssertEqual(stats.totalCacheRead, 20)
        XCTAssertEqual(stats.totalCacheWrite, 10)
        XCTAssertEqual(stats.totalReasoningTokens, 25)
        XCTAssertEqual(stats.projects.count, 1)
        XCTAssertEqual(stats.projects.first?.name, "MyApp")
        XCTAssertEqual(try XCTUnwrap(stats.projects.first).cost, 1.50, accuracy: 0.001)
        XCTAssertEqual(stats.modelUsage.count, 1)
        XCTAssertEqual(stats.modelUsage.first?.model, "claude-sonnet-4")
        XCTAssertEqual(try XCTUnwrap(stats.modelUsage.first).cost, 1.50, accuracy: 0.001)
    }

    func test_multipleSessionsAcrossProjects() throws {
        let projA = lastID()
        let projB = lastID()
        let sessA1 = lastID()
        let sessA2 = lastID()
        let sessB = lastID()
        let now = Date()

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projA)', 'ProjectA', '/a')")
        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projB)', 'ProjectB', '/b')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessA1)', '\(projA)', NULL, 'SessA1', 'a1', \(ms(now)), \(ms(now)))")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessA2)', '\(projA)', NULL, 'SessA2', 'a2', \(ms(now)), \(ms(now)))")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessB)', '\(projB)', NULL, 'SessB', 'b1', \(ms(now)), \(ms(now)))")

        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessA1)', \(ms(now)), '{\"role\":\"assistant\",\"cost\":2.00,\"tokens\":{},\"providerID\":\"openai\",\"modelID\":\"gpt-4\"}')")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessA2)', \(ms(now)), '{\"role\":\"assistant\",\"cost\":3.00,\"tokens\":{},\"providerID\":\"openai\",\"modelID\":\"gpt-4\"}')")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessB)', \(ms(now)), '{\"role\":\"assistant\",\"cost\":5.00,\"tokens\":{},\"providerID\":\"anthropic\",\"modelID\":\"claude-sonnet-4\"}')")

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.sessionCount, 3)
        XCTAssertEqual(stats.totalCost, 10.00, accuracy: 0.001)
        XCTAssertEqual(stats.projects.count, 2)
        XCTAssertEqual(try XCTUnwrap(stats.projects.first(where: { $0.name == "ProjectA" })).cost, 5.00, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(stats.projects.first(where: { $0.name == "ProjectB" })).cost, 5.00, accuracy: 0.001)
        XCTAssertEqual(stats.modelUsage.count, 2)
    }

    func test_timeFilter_respected() throws {
        let projectID = lastID()
        let oldSession = lastID()
        let newSession = lastID()
        let oldDate = Date().addingTimeInterval(-20 * 86400)
        let recentDate = Date().addingTimeInterval(-2 * 86400)

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(oldSession)', '\(projectID)', NULL, 'Old', 'old', \(ms(oldDate)), \(ms(oldDate)))")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(newSession)', '\(projectID)', NULL, 'New', 'new', \(ms(recentDate)), \(ms(recentDate)))")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(oldSession)', \(ms(oldDate)), '{\"role\":\"assistant\",\"cost\":10.00,\"tokens\":{},\"providerID\":\"openai\",\"modelID\":\"gpt-4\"}')")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(newSession)', \(ms(recentDate)), '{\"role\":\"assistant\",\"cost\":2.00,\"tokens\":{},\"providerID\":\"openai\",\"modelID\":\"gpt-4\"}')")

        sut = makeSUT()
        sut.daysFilter = 7

        let stats = try sut.loadStats()
        XCTAssertEqual(stats.sessionCount, 1)
        XCTAssertEqual(stats.totalCost, 2.00, accuracy: 0.001)
        XCTAssertEqual(stats.messageCount, 1)
    }

    func test_toolUsage_correctlyAggregated() throws {
        let projectID = lastID()
        let sessionID = lastID()
        let now = Date()

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessionID)', '\(projectID)', NULL, 'S', 's', \(ms(now)), \(ms(now)))")
        exec("INSERT INTO part (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(now)), '{\"type\":\"tool\",\"tool\":\"read\"}')")
        exec("INSERT INTO part (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(now)), '{\"type\":\"tool\",\"tool\":\"read\"}')")
        exec("INSERT INTO part (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(now)), '{\"type\":\"tool\",\"tool\":\"edit\"}')")

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.toolUsage.count, 2)
        let readTool = stats.toolUsage.first(where: { $0.name == "read" })
        let editTool = stats.toolUsage.first(where: { $0.name == "edit" })
        XCTAssertNotNil(readTool)
        XCTAssertNotNil(editTool)

        if let readTool = readTool, let editTool = editTool {
            XCTAssertEqual(readTool.count, 2)
            XCTAssertEqual(editTool.count, 1)
            XCTAssertEqual(readTool.percentage, 66.7, accuracy: 0.5)
            XCTAssertEqual(editTool.percentage, 33.3, accuracy: 0.5)
        }
    }

    func test_todayCost_onlyIncludesToday() throws {
        let projectID = lastID()
        let sessionID = lastID()
        let today = Date()
        let yesterday = Date().addingTimeInterval(-86400)

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessionID)', '\(projectID)', NULL, 'S', 's', \(ms(today)), \(ms(today)))")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(yesterday)), '{\"role\":\"assistant\",\"cost\":5.00,\"tokens\":{},\"providerID\":\"o\",\"modelID\":\"m\"}')")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(today)), '{\"role\":\"assistant\",\"cost\":3.00,\"tokens\":{},\"providerID\":\"o\",\"modelID\":\"m\"}')")

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.totalCost, 8.00, accuracy: 0.001)
        XCTAssertEqual(stats.todayCost, 3.00, accuracy: 0.001)
    }

    func test_totalCostForCurrentMonth() throws {
        let projectID = lastID()
        let sessionID = lastID()
        let thisMonth = Date()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: thisMonth)!

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessionID)', '\(projectID)', NULL, 'S', 's', \(ms(thisMonth)), \(ms(thisMonth)))")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(lastMonth)), '{\"role\":\"assistant\",\"cost\":10.00,\"tokens\":{},\"providerID\":\"o\",\"modelID\":\"m\"}')")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(sessionID)', \(ms(thisMonth)), '{\"role\":\"assistant\",\"cost\":7.50,\"tokens\":{},\"providerID\":\"o\",\"modelID\":\"m\"}')")

        sut = makeSUT()
        let cost = try sut.totalCostForCurrentMonth()

        XCTAssertEqual(cost, 7.50, accuracy: 0.001)
    }

    func test_parentSession_excludedFromCount() throws {
        let projectID = lastID()
        let parentSess = lastID()
        let childSess = lastID()
        let now = Date()

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(parentSess)', '\(projectID)', NULL, 'Parent', 'p', \(ms(now)), \(ms(now)))")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(childSess)', '\(projectID)', '\(parentSess)', 'Child', 'c', \(ms(now)), \(ms(now)))")
        exec("INSERT INTO message (id, session_id, time_created, data) VALUES ('\(lastID())', '\(parentSess)', \(ms(now)), '{\"role\":\"assistant\",\"cost\":1.00,\"tokens\":{},\"providerID\":\"o\",\"modelID\":\"m\"}')")

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.sessionCount, 1)
        XCTAssertEqual(stats.totalCost, 1.00, accuracy: 0.001)
    }

    func test_noAssistantMessages_stillCountsSession() throws {
        let projectID = lastID()
        let sessionID = lastID()
        let now = Date()

        exec("INSERT INTO project (id, name, worktree) VALUES ('\(projectID)', 'MyApp', '/app')")
        exec("INSERT INTO session (id, project_id, parent_id, title, slug, time_created, time_updated) VALUES ('\(sessionID)', '\(projectID)', NULL, 'No Msgs', 'none', \(ms(now)), \(ms(now)))")

        sut = makeSUT()
        let stats = try sut.loadStats()

        XCTAssertEqual(stats.sessionCount, 1)
        XCTAssertEqual(stats.messageCount, 0)
        XCTAssertEqual(stats.totalCost, 0)
        XCTAssertEqual(stats.projects.count, 1)
        XCTAssertEqual(stats.modelUsage.count, 0)
    }
}

