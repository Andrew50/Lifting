//
//  StrengthProgressView.swift
//  Lifting
//

import SwiftUI

struct StrengthProgressView: View {
    @ObservedObject var workoutStore: WorkoutStore

    @State private var keyLifts: [KeyLiftCardData] = []
    @State private var recentPRs: [PRFeedItem] = []
    @State private var isShowingMoreExercises = false
    @State private var selectedExerciseId: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                keyLiftsSection
                moreExercisesButton
                recentPRsSection
                Spacer().frame(height: 40)
            }
            .padding(.top, 16)
        }
        .onAppear {
            reload()
        }
        .sheet(isPresented: $isShowingMoreExercises) {
            MoreExercisesSheet(
                workoutStore: workoutStore,
                onSelect: { exerciseId in
                    selectedExerciseId = exerciseId
                    isShowingMoreExercises = false
                }
            )
        }
        .navigationDestination(item: $selectedExerciseId) { exerciseId in
            ExerciseStrengthDetailView(
                workoutStore: workoutStore,
                exerciseId: exerciseId
            )
        }
    }

    private var keyLiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key Lifts")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(keyLifts) { lift in
                    Button {
                        selectedExerciseId = lift.id
                    } label: {
                        keyLiftCard(lift)
                    }
                    .buttonStyle(.plain)
                    .disabled(!lift.hasData)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func keyLiftCard(_ lift: KeyLiftCardData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lift.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            if let oneRM = lift.currentOneRM {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", oneRM))
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("lbs")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if let change = lift.change {
                    HStack(spacing: 3) {
                        Image(systemName: change > 0 ? "arrow.up" : (change < 0 ? "arrow.down" : "minus"))
                            .font(.system(size: 9, weight: .bold))
                        Text(change == 0 ? "same" : String(format: "%.0f lbs", abs(change)))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(
                        change > 0
                            ? AppTheme.accent
                            : change < 0 ? Color(hex: "#DC2626") : AppTheme.textTertiary
                    )
                } else {
                    Text("est. 1RM")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            } else {
                Text("—")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Not trained yet")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .opacity(lift.hasData ? 1.0 : 0.65)
    }

    private var moreExercisesButton: some View {
        Button {
            isShowingMoreExercises = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text("More exercises")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .padding(14)
            .background(AppTheme.accentLighter)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var recentPRsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent PRs")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

            if recentPRs.isEmpty {
                emptyPRs
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentPRs.enumerated()), id: \.element.id) { index, pr in
                        prRow(pr)
                        if index < recentPRs.count - 1 {
                            Divider().background(AppTheme.fieldBorder).padding(.leading, 54)
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
    }

    private func prRow(_ pr: PRFeedItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#D97706"))
                .frame(width: 32, height: 32)
                .background(Color(hex: "#FEF3C7"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(
                    "\(String(format: "%.0f", pr.weight)) × \(pr.reps) · Est. 1RM \(String(format: "%.0f", pr.estimatedOneRM)) lbs"
                )
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(formatPRDate(pr.achievedAt))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(12)
    }

    private var emptyPRs: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No PRs yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Complete a workout to start tracking PRs")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func reload() {
        keyLifts = (try? workoutStore.fetchKeyLiftsData()) ?? []
        recentPRs = (try? workoutStore.fetchRecentPRs(limit: 20)) ?? []
    }

    private func formatPRDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Placeholders (expand in a later step)

struct MoreExercisesSheet: View {
    @ObservedObject var workoutStore: WorkoutStore
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("All exercises list — coming soon")
                .foregroundStyle(AppTheme.textSecondary)
                .navigationTitle("All Exercises")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

struct ExerciseStrengthDetailView: View {
    @ObservedObject var workoutStore: WorkoutStore
    let exerciseId: String

    var body: some View {
        VStack {
            Text("Strength detail — coming soon")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .navigationTitle("Exercise Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
