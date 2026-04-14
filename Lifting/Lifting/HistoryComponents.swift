//
//  HistoryComponents.swift
//  Lifting
//

import SwiftUI

struct HistoryBubble<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct HistoryBubbleHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

struct HistoryDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.fieldBorder)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

struct HistorySetRow: View {
    let setNumber: Int
    /// Weight in lbs (stored canonical).
    let weight: Double?
    let reps: Int?
    let rir: Double?
    let isWarmUp: Bool?
    let isDropSet: Bool?
    let restTimerSeconds: Int?
    let displayWeightUnit: String
    let displayIntensityDisplay: String

    private var displayWeight: Double? {
        guard let lbs = weight else { return nil }
        return displayWeightUnit == "kg" ? lbs / 2.20462 : lbs
    }

    private var displayIntensityValue: Double? {
        guard let r = rir else { return nil }
        return displayIntensityDisplay == "rpe" ? (10 - r) : r
    }

    private var intensityLabel: String {
        displayIntensityDisplay == "rpe" ? "RPE" : "RIR"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text("Set \(setNumber)")
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 44, alignment: .leading)

                HStack(spacing: 4) {
                    if let w = displayWeight {
                        let unitSuffix = displayWeightUnit == "kg" ? " kg" : " lbs"
                        Text(String(format: "%.1f", w) + unitSuffix)
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(AppTheme.textPrimary)
                    } else {
                        Text("—")
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    if let r = reps {
                        Text("× \(r)")
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if rir != nil {
                        if rir == 0 {
                            Text("Failure")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        } else if let val = displayIntensityValue {
                            let str = val == Double(Int(val)) ? String(Int(val)) : String(format: "%.1f", val)
                            Text("\(intensityLabel) \(str)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accentLight)
                                .foregroundStyle(AppTheme.accentText)
                                .clipShape(Capsule())
                        }
                    }

                    if isWarmUp == true {
                        Text("W")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.warmupBackground)
                            .foregroundStyle(AppTheme.warmupText)
                            .clipShape(Circle())
                    }

                    if isDropSet == true {
                        Text("D")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.dropSetBackground)
                            .foregroundStyle(AppTheme.dropSetText)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.vertical, 2)

            if let restSeconds = restTimerSeconds, restSeconds > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("Rest: \(restSeconds < 60 ? "\(restSeconds)s" : "\(restSeconds / 60):\(String(format: "%02d", restSeconds % 60))")")
                        .font(.caption2)
                }
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.leading, 56)
                .padding(.bottom, 4)
            }
        }
    }
}

struct HistoryWorkoutSummaryContent: View {
    let exercises: [WorkoutExerciseSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(exercises) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(exerciseSummaryText(exercise))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func exerciseSummaryText(_ exercise: WorkoutExerciseSummary) -> String {
        let sets = exercise.setsCount
        if let weight = exercise.topWeight, let reps = exercise.topReps, weight > 0 {
            let weightStr = weight == Double(Int(weight))
                ? String(Int(weight))
                : String(format: "%.1f", weight)
            return "\(sets) \(sets == 1 ? "set" : "sets") · \(weightStr) × \(reps)"
        }
        return "\(sets) \(sets == 1 ? "set" : "sets")"
    }
}
