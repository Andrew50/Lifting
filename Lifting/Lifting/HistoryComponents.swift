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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HistoryBubbleHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.bold))

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HistoryDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
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
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                HStack(spacing: 4) {
                    if let w = displayWeight {
                        let unitSuffix = displayWeightUnit == "kg" ? " kg" : " lbs"
                        Text(String(format: "%.1f", w) + unitSuffix)
                            .font(.body.monospacedDigit())
                    } else {
                        Text("—")
                            .foregroundStyle(.tertiary)
                    }

                    if let r = reps {
                        Text("× \(r)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
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
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    if isWarmUp == true {
                        Text("W")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2))
                            .foregroundStyle(.orange)
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
                .foregroundStyle(.secondary)
                .padding(.leading, 56)
                .padding(.bottom, 4)
            }
        }
    }
}

struct HistoryWorkoutSummaryContent: View {
    let exercises: [WorkoutExerciseSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(exercises) { exercise in
                Text("\(exercise.setsCount)x \(exercise.name)")
                    .font(.footnote)
            }
        }
    }
}
