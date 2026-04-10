//
//  ContentView.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import SwiftUI
import Charts

// MARK: - Main Stats View

struct StatsView: View {
    @StateObject private var db = OpenCodeDatabase.shared
    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case sessions = "Sessions"
        case models = "Models"
        case projects = "Projects"

        var shortLabel: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !db.dbExists {
                dbNotFoundView
            } else if let error = db.error {
                errorView(error)
            } else {
                tabBar
                Divider()

                ScrollView(showsIndicators: false) {
                    switch selectedTab {
                    case .overview: OverviewTab(stats: db.stats)
                    case .sessions: SessionsTab(sessions: db.stats.recentSessions)
                    case .models: ModelsTab(stats: db.stats)
                    case .projects: ProjectsTab(stats: db.stats)
                    }
                }
            }
        }
        .frame(width: 360, height: 520)
        .onAppear { db.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("opencode-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 16)
            Text("OpenCode Stats")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Menu {
                Button("All Time") { db.daysFilter = nil; db.refresh() }
                Divider()
                Button("Last 7 Days") { db.daysFilter = 7; db.refresh() }
                Button("Last 30 Days") { db.daysFilter = 30; db.refresh() }
                Button("Last 90 Days") { db.daysFilter = 90; db.refresh() }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                    Text(filterLabel)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .fixedSize()

            if db.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    db.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var filterLabel: String {
        if let days = db.daysFilter { return "\(days)d" }
        return "All"
    }

    private var tabBar: some View {
        FullWidthSegmentedControl(
            items: Tab.allCases.map(\.shortLabel),
            selection: Binding(
                get: { Tab.allCases.firstIndex(of: selectedTab) ?? 0 },
                set: { selectedTab = Tab.allCases[$0] }
            )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var dbNotFoundView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "externaldrive.trianglebadge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("OpenCode Database Not Found")
                .font(.headline)
            Text("Make sure OpenCode is installed and has been run at least once.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Error Loading Stats")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { db.refresh() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let stats: OpenCodeStats

    private var totalTokens: Int64 {
        stats.totalInputTokens + stats.totalOutputTokens + stats.totalCacheRead + stats.totalCacheWrite + stats.totalReasoningTokens
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                MetricCard(title: "Total Cost", value: Formatters.currency(stats.totalCost), icon: "dollarsign.circle.fill", color: .green)
                MetricCard(title: "Sessions", value: Formatters.number(stats.sessionCount), icon: "bubble.left.and.bubble.right.fill", color: .blue)
                MetricCard(title: "Messages", value: Formatters.number(stats.messageCount), icon: "message.fill", color: .purple)
                MetricCard(title: "Days Active", value: "\(stats.dayCount)", icon: "calendar", color: .orange)
                MetricCard(title: "Avg Cost/Day", value: Formatters.currency(stats.avgCostPerDay), icon: "chart.line.uptrend.xyaxis", color: .teal)
                MetricCard(title: "Today", value: Formatters.currency(stats.todayCost), icon: "clock.fill", color: .red)
            }

            // Daily cost chart
            if stats.dailyCosts.count > 1 {
                SectionHeader(title: "Daily Spend (Last 30 Days)")
                DailyCostChart(data: stats.dailyCosts)
            }

            if !stats.projects.isEmpty {
                SectionHeader(title: "Top Projects by Cost")
                GroupedList(items: Array(stats.projects.prefix(5)), dividerLeading: 30) { project in
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(project.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(project.sessionCount) sessions")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(Formatters.currency(project.cost))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
            }

            if !stats.modelUsage.isEmpty {
                SectionHeader(title: "Top Models by Cost")
                GroupedList(items: Array(stats.modelUsage.prefix(5)), dividerLeading: 34) { model in
                    HStack(spacing: 8) {
                        ProviderIcon(provider: model.provider, model: model.model, size: 16)
                        Text(model.model)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.number(model.count) + " msgs")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(Formatters.currency(model.cost))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                }
            }

            // Token breakdown
            SectionHeader(title: "Token Breakdown")
            VStack(spacing: 8) {
                TokenRow(label: "Input", value: stats.totalInputTokens, total: totalTokens, color: .blue)
                TokenRow(label: "Output", value: stats.totalOutputTokens, total: totalTokens, color: .green)
                TokenRow(label: "Reasoning", value: stats.totalReasoningTokens, total: totalTokens, color: .purple)
                TokenRow(label: "Cache Read", value: stats.totalCacheRead, total: totalTokens, color: .orange)
                TokenRow(label: "Cache Write", value: stats.totalCacheWrite, total: totalTokens, color: .teal)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            // Tool usage (top 10)
            if !stats.toolUsage.isEmpty {
                SectionHeader(title: "Tool Usage")
                VStack(spacing: 0) {
                    ForEach(Array(stats.toolUsage.prefix(10).enumerated()), id: \.element.id) { index, tool in
                        ToolRow(tool: tool, maxCount: stats.toolUsage.first?.count ?? 1)
                        if index < min(stats.toolUsage.count, 10) - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

            // MCP Servers
            if !stats.mcpServers.isEmpty {
                SectionHeader(title: "MCP Servers")
                GroupedList(items: stats.mcpServers, dividerLeading: 40) { server in
                    HStack(spacing: 10) {
                        Image(systemName: server.type == .remote ? "globe" : "terminal")
                            .font(.system(size: 12))
                            .foregroundStyle(server.type == .remote ? .blue : .orange)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(server.name)
                                .font(.system(size: 11, weight: .medium))
                            Text(server.detail)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(server.type.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(server.type == .remote ? .blue : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (server.type == .remote ? Color.blue : Color.orange).opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Tokens Tab

struct TokensTab: View {
    let stats: OpenCodeStats

    private var totalTokens: Int64 {
        stats.totalInputTokens + stats.totalOutputTokens + stats.totalCacheRead + stats.totalCacheWrite + stats.totalReasoningTokens
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCard(title: "Total Cost", value: Formatters.currency(stats.totalCost), icon: "dollarsign.circle.fill", color: .green)
                MetricCard(title: "Avg/Session", value: Formatters.tokens(stats.avgTokensPerSession), icon: "number.circle.fill", color: .blue)
                MetricCard(title: "Median/Session", value: Formatters.tokens(stats.medianTokensPerSession), icon: "number.circle", color: .cyan)
            }

            SectionHeader(title: "Token Breakdown")

            VStack(spacing: 8) {
                TokenRow(label: "Input", value: stats.totalInputTokens, total: totalTokens, color: .blue)
                TokenRow(label: "Output", value: stats.totalOutputTokens, total: totalTokens, color: .green)
                TokenRow(label: "Reasoning", value: stats.totalReasoningTokens, total: totalTokens, color: .purple)
                TokenRow(label: "Cache Read", value: stats.totalCacheRead, total: totalTokens, color: .orange)
                TokenRow(label: "Cache Write", value: stats.totalCacheWrite, total: totalTokens, color: .teal)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
    }
}

struct TokenRow: View {
    let label: String
    let value: Int64
    let total: Int64
    let color: Color

    private var fraction: Double {
        total > 0 ? Double(value) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(Formatters.tokens(value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(Formatters.percentage(fraction * 100))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Tools Tab

struct ToolsTab: View {
    let stats: OpenCodeStats

    var body: some View {
        VStack(spacing: 0) {
            let totalTools = stats.toolUsage.reduce(0) { $0 + $1.count }
            HStack {
                Text("Total Tool Calls")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.number(totalTools))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().padding(.leading, 12)

            ForEach(Array(stats.toolUsage.enumerated()), id: \.element.id) { index, tool in
                ToolRow(tool: tool, maxCount: stats.toolUsage.first?.count ?? 1)
                if index < stats.toolUsage.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }
}

struct ToolRow: View {
    let tool: ToolUsageItem
    let maxCount: Int

    private var barFraction: Double {
        maxCount > 0 ? Double(tool.count) / Double(maxCount) : 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(tool.name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor).opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(0, geo.size.width * barFraction))
                }
            }
            .frame(height: 12)

            Text(Formatters.number(tool.count))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .frame(width: 40, alignment: .trailing)

            Text(Formatters.percentage(tool.percentage))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Models Tab

struct ModelsTab: View {
    let stats: OpenCodeStats

    var body: some View {
        VStack(spacing: 12) {
            if stats.modelUsage.isEmpty {
                EmptyState(icon: "cpu", message: "No model usage data")
            } else {
                GroupedList(items: stats.modelUsage, dividerLeading: 44) { model in
                    HStack(spacing: 10) {
                        ProviderIcon(provider: model.provider, model: model.model, size: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.model)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Text(model.provider)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.currency(model.cost))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            Text("\(Formatters.number(model.count)) messages")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Sessions Tab

struct SessionsTab: View {
    let sessions: [RecentSession]

    var body: some View {
        VStack(spacing: 12) {
            if sessions.isEmpty {
                EmptyState(icon: "bubble.left.and.bubble.right", message: "No recent sessions")
            } else {
                GroupedList(items: sessions, dividerLeading: 12) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(Formatters.currency(session.cost))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        HStack(spacing: 6) {
                            ProviderIcon(provider: session.provider, model: session.model, size: 10)
                            Text(session.model)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text("·")
                                .foregroundStyle(.quaternary)

                            Image(systemName: "folder")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(session.projectName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(session.messageCount) msgs")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)

                            Text(timeAgo(session.date))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Daily Cost Chart

struct DailyCostChart: View {
    let data: [DailyCost]

    private var parsedData: [(date: Date, cost: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return data.compactMap { item in
            guard let date = formatter.date(from: item.date) else { return nil }
            return (date: date, cost: item.cost)
        }
    }

    var body: some View {
        Chart(parsedData, id: \.date) { item in
            BarMark(
                x: .value("Date", item.date, unit: .day),
                y: .value("Cost", item.cost)
            )
            .foregroundStyle(Color.green.gradient)
            .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                AxisValueLabel {
                    if let cost = value.as(Double.self) {
                        Text("$\(Int(cost))")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .frame(height: 100)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Projects Tab

struct ProjectsTab: View {
    let stats: OpenCodeStats

    var body: some View {
        VStack(spacing: 12) {
            if stats.projects.isEmpty {
                EmptyState(icon: "folder", message: "No project data")
            } else {
                GroupedList(items: stats.projects, dividerLeading: 40) { project in
                    ProjectRow(project: project)
                }
            }
        }
        .padding(12)
    }
}

struct ProjectRow: View {
    let project: ProjectStats
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                        .frame(width: 20)

                    Text(project.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(Formatters.currency(project.cost))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    DetailRow(label: "Sessions", value: Formatters.number(project.sessionCount))
                    DetailRow(label: "Messages", value: Formatters.number(project.messageCount))
                    DetailRow(label: "Input Tokens", value: Formatters.tokens(project.inputTokens))
                    DetailRow(label: "Output Tokens", value: Formatters.tokens(project.outputTokens))
                    DetailRow(label: "Cache Read", value: Formatters.tokens(project.cacheRead))
                    DetailRow(label: "Cache Write", value: Formatters.tokens(project.cacheWrite))
                    HStack {
                        Text(project.path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
                .padding(.leading, 28)
                .transition(.opacity)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared Components

struct GroupedList<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    var dividerLeading: CGFloat = 12
    @ViewBuilder let rowContent: (Item) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                rowContent(item)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                if index < items.count - 1 {
                    Divider().padding(.leading, dividerLeading)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }
}

struct EmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Full Width Segmented Control

struct FullWidthSegmentedControl: NSViewRepresentable {
    let items: [String]
    @Binding var selection: Int

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: items, trackingMode: .selectOne, target: context.coordinator, action: #selector(Coordinator.selectionChanged(_:)))
        control.segmentDistribution = .fillEqually
        control.selectedSegment = selection
        control.segmentStyle = .rounded
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        control.selectedSegment = selection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: FullWidthSegmentedControl
        init(_ parent: FullWidthSegmentedControl) { self.parent = parent }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            parent.selection = sender.selectedSegment
        }
    }
}
