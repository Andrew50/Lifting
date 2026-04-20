//
//  BodyWeightProgressView.swift
//  Lifting
//

import Charts
import SwiftUI

enum WeightTimeRange: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .all: return nil
        }
    }
}

private enum GroupingMode {
    case flat
    case byWeek
    case byMonth
}

private struct WeekGroup: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let entries: [BodyWeightEntryRecord]

    var averageWeight: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0.0) { $0 + $1.weight } / Double(entries.count)
    }

    var weeklyChange: Double? {
        let ordered = entries.sorted(by: { $0.date < $1.date })
        guard let first = ordered.first,
              let last = ordered.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }

    var displayLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let weeksAgo = calendar.dateComponents([.weekOfYear], from: startDate, to: now).weekOfYear ?? 0
        if weeksAgo == 0 { return "This week" }
        if weeksAgo == 1 { return "Last week" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}

private struct MonthGroup: Identifiable {
    let id: String
    let month: Date
    let weeks: [WeekGroup]

    var totalEntries: Int {
        weeks.reduce(0) { $0 + $1.entries.count }
    }

    var averageWeight: Double {
        let allEntries = weeks.flatMap { $0.entries }
        guard !allEntries.isEmpty else { return 0 }
        return allEntries.reduce(0.0) { $0 + $1.weight } / Double(allEntries.count)
    }

    var monthlyChange: Double? {
        let allEntries = weeks.flatMap { $0.entries }.sorted { $0.date < $1.date }
        guard let first = allEntries.first,
              let last = allEntries.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }

    var displayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }
}

struct BodyWeightProgressView: View {
    @ObservedObject var bodyWeightStore: BodyWeightStore
    @State private var selectedRange: WeightTimeRange = .month
    @State private var isShowingLogSheet = false
    @State private var entryToEdit: BodyWeightEntryRecord? = nil
    @State private var expandedWeeks: Set<String> = []
    @State private var expandedMonths: Set<String> = []

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timeRangeSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if bodyWeightStore.recentEntries.isEmpty {
                        emptyState
                    } else if filteredEntries.isEmpty {
                        rangeEmptyState
                    } else {
                        weightHero
                            .padding(.horizontal, 16)

                        chartCard
                            .padding(.horizontal, 16)

                        entriesSection
                    }

                    Spacer().frame(height: 100)
                }
            }

            Button {
                entryToEdit = nil
                isShowingLogSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Log Weight")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $isShowingLogSheet) {
            WeightLogSheet(
                bodyWeightStore: bodyWeightStore,
                existingEntry: entryToEdit,
                onDismiss: {
                    isShowingLogSheet = false
                    entryToEdit = nil
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Data

    private var filteredEntries: [BodyWeightEntryRecord] {
        let all = bodyWeightStore.recentEntries
        guard let days = selectedRange.days else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let cutoffStr = BodyWeightStore.dateString(from: cutoff)
        return all.filter { $0.date >= cutoffStr }
    }

    private var sortedEntries: [BodyWeightEntryRecord] {
        filteredEntries.sorted { $0.date < $1.date }
    }

    private var currentWeight: Double? {
        bodyWeightStore.latestEntry?.weight
    }

    private var rangeChange: Double? {
        guard let first = sortedEntries.first,
              let last = sortedEntries.last,
              first.id != last.id else { return nil }
        return last.weight - first.weight
    }

    private var groupingMode: GroupingMode {
        switch selectedRange {
        case .week: return .flat
        case .month, .threeMonths, .sixMonths: return .byWeek
        case .year, .all: return .byMonth
        }
    }

    private func groupByWeek(_ entries: [BodyWeightEntryRecord]) -> [WeekGroup] {
        let calendar = Calendar.current
        var weekMap: [String: [BodyWeightEntryRecord]] = [:]

        for entry in entries {
            guard let date = DateFormatter.yyyymmdd.date(from: entry.date) else { continue }
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let key = "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
            weekMap[key, default: []].append(entry)
        }

        return weekMap.compactMap { key, entries in
            guard let first = entries.map({ DateFormatter.yyyymmdd.date(from: $0.date) ?? Date() }).min() else {
                return nil
            }
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: first)
            let start = weekInterval?.start ?? first
            let end = weekInterval?.end.addingTimeInterval(-1) ?? first
            return WeekGroup(
                id: key,
                startDate: start,
                endDate: end,
                entries: entries.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.startDate > $1.startDate }
    }

    private func groupByMonth(_ entries: [BodyWeightEntryRecord]) -> [MonthGroup] {
        let calendar = Calendar.current
        var monthMap: [String: [BodyWeightEntryRecord]] = [:]

        for entry in entries {
            guard let date = DateFormatter.yyyymmdd.date(from: entry.date) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            let key = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
            monthMap[key, default: []].append(entry)
        }

        return monthMap.compactMap { key, entries in
            guard let first = entries.map({ DateFormatter.yyyymmdd.date(from: $0.date) ?? Date() }).min() else {
                return nil
            }
            let monthInterval = calendar.dateInterval(of: .month, for: first)
            let monthStart = monthInterval?.start ?? first
            return MonthGroup(
                id: key,
                month: monthStart,
                weeks: groupByWeek(entries)
            )
        }
        .sorted { $0.month > $1.month }
    }

    // MARK: - Views

    private var timeRangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(WeightTimeRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedRange == range ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedRange == range ? AppTheme.accent : AppTheme.fieldBackground)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weightHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", currentWeight ?? 0))
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("lbs")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let change = rangeChange {
                HStack(spacing: 4) {
                    Image(systemName: change <= 0 ? "arrow.down" : "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(String(format: "%.1f", abs(change))) lbs in \(selectedRange.rawValue)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(changeColor(for: change))
            }
        }
    }

    private var chartCard: some View {
        VStack(spacing: 0) {
            Chart(sortedEntries, id: \.id) { entry in
                let date = dateFromString(entry.date)

                AreaMark(
                    x: .value("Date", date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.2), AppTheme.accent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(AppTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(AppTheme.accent)
                .symbolSize(36)
            }
            .frame(height: 200)
            .chartYScale(domain: yAxisDomain)
            .padding(.vertical, 16)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var yAxisDomain: ClosedRange<Double> {
        let weights = sortedEntries.map { $0.weight }
        guard let minW = weights.min(), let maxW = weights.max() else {
            return 0...200
        }
        let padding = (maxW - minW) * 0.2
        let lowerBound = minW - Swift.max(padding, 1)
        let upperBound = maxW + Swift.max(padding, 1)
        return lowerBound...upperBound
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Entries")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Group {
                switch groupingMode {
                case .flat:
                    flatEntriesView
                case .byWeek:
                    weekGroupedView
                case .byMonth:
                    monthGroupedView
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var flatEntriesView: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                entryRow(entry)
                if index < filteredEntries.count - 1 {
                    Divider().background(AppTheme.fieldBorder).padding(.leading, 14)
                }
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var weekGroupedView: some View {
        VStack(spacing: 10) {
            ForEach(groupByWeek(filteredEntries)) { week in
                weekGroupRow(week)
            }
        }
    }

    private var monthGroupedView: some View {
        VStack(spacing: 10) {
            ForEach(groupByMonth(filteredEntries)) { month in
                monthGroupRow(month)
            }
        }
    }

    private func weekGroupRow(_ week: WeekGroup) -> some View {
        let isExpanded = expandedWeeks.contains(week.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedWeeks.remove(week.id)
                    } else {
                        expandedWeeks.insert(week.id)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(week.displayLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f lbs avg", week.averageWeight))
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            if let change = week.weeklyChange {
                                Text("·")
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text("\(change <= 0 ? "▼" : "▲") \(String(format: "%.1f lbs", abs(change)))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(change <= 0 ? AppTheme.accent : Color(hex: "#DC2626"))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(AppTheme.fieldBorder).padding(.leading, 14)
                VStack(spacing: 0) {
                    ForEach(Array(week.entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry)
                        if index < week.entries.count - 1 {
                            Divider().background(AppTheme.fieldBorder).padding(.leading, 14)
                        }
                    }
                }
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func monthGroupRow(_ month: MonthGroup) -> some View {
        let isExpanded = expandedMonths.contains(month.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedMonths.remove(month.id)
                    } else {
                        expandedMonths.insert(month.id)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(month.displayLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f lbs avg", month.averageWeight))
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("·")
                                .foregroundStyle(AppTheme.textTertiary)
                            Text("\(month.totalEntries) entries")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                            if let change = month.monthlyChange {
                                Text("·")
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text("\(change <= 0 ? "▼" : "▲") \(String(format: "%.1f lbs", abs(change)))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(change <= 0 ? AppTheme.accent : Color(hex: "#DC2626"))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(AppTheme.fieldBorder).padding(.leading, 14)
                VStack(spacing: 8) {
                    ForEach(month.weeks) { week in
                        nestedWeekRow(week)
                    }
                }
                .padding(10)
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func nestedWeekRow(_ week: WeekGroup) -> some View {
        let isExpanded = expandedWeeks.contains(week.id)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedWeeks.remove(week.id)
                    } else {
                        expandedWeeks.insert(week.id)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(week.displayLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(String(format: "%.1f lbs avg", week.averageWeight))
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if let change = week.weeklyChange {
                        Text("\(change <= 0 ? "▼" : "▲") \(String(format: "%.1f", abs(change)))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(change <= 0 ? AppTheme.accent : Color(hex: "#DC2626"))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .padding(.leading, 6)
                }
                .padding(10)
            }
            .buttonStyle(.plain)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(week.entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry)
                        if index < week.entries.count - 1 {
                            Divider().background(AppTheme.fieldBorder).padding(.leading, 14)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func entryRow(_ entry: BodyWeightEntryRecord) -> some View {
        Button {
            entryToEdit = entry
            isShowingLogSheet = true
        } label: {
            HStack {
                Text(formatEntryDate(entry.date))
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(String(format: "%.1f lbs", entry.weight))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "scalemass")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No weight logged yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Tap Log Weight to start tracking")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var rangeEmptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 48)
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No entries in this range")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Try a wider range like 1M or All, or log a new weight.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func dateFromString(_ str: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str) ?? Date()
    }

    private func formatEntryDate(_ str: String) -> String {
        let date = dateFromString(str)
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func changeColor(for change: Double) -> Color {
        // TODO: wire to user's fitness goal from OnboardingStore
        if change < -0.3 { return AppTheme.accent }
        if change > 0.3 { return Color(hex: "#DC2626") }
        return AppTheme.textSecondary
    }
}
