//
//  ActiveWorkoutSheetView.swift
//  Lifting
//

import SwiftUI

struct ActiveWorkoutSheetView: View {
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var exerciseStore: ExerciseStore

    let workoutId: String
    let onDismiss: () -> Void

    @State private var restTimeSeconds: Int = 120
    @State private var showRestTimePicker = false
    @State private var isFinishing = false
    @State private var workoutStartedAt: TimeInterval?

    private let restTimeOptions = [30, 45, 60, 90, 120, 180]

    private func formatElapsed(_ startedAt: TimeInterval?) -> String {
        guard let start = startedAt else { return "0:00" }
        let end = Date().timeIntervalSince1970
        let total = max(0, Int(end - start))
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: clock (left), elapsed timer (center), Finish (right)
            ZStack {
                // Center: elapsed timer
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(formatElapsed(workoutStartedAt))
                        .font(.title3.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    // Left: clock button
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showRestTimePicker.toggle()
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Spacer()

                    // Right: Finish button
                    Button {
                        finishWorkout()
                    } label: {
                        Text("Finish")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isFinishing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)

            if showRestTimePicker {
                restTimePickerSection
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
            }

            NavigationStack {
                WorkoutEditorView(
                    templateStore: templateStore,
                    workoutStore: workoutStore,
                    exerciseStore: exerciseStore,
                    subject: .workout(id: workoutId),
                    onFinish: onDismiss,
                    restTimeSeconds: $restTimeSeconds
                )
            }
        }
        .background(Color.white)
        .onAppear {
            if let workout = try? workoutStore.fetchWorkout(workoutId: workoutId) {
                workoutStartedAt = workout.startedAt
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRestTimePicker)
    }

    private var restTimePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rest time between sets")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(restTimeOptions, id: \.self) { seconds in
                        let isSelected = restTimeSeconds == seconds
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                restTimeSeconds = seconds
                            }
                        } label: {
                            Text(seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min")
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.green : Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }

    private func finishWorkout() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isFinishing = true
        }
        do {
            try workoutStore.completeWorkout(workoutId: workoutId)
        } catch {}
        withAnimation(.easeOut(duration: 0.25)) {
            onDismiss()
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ActiveWorkoutSheetView(
        templateStore: AppContainer().templateStore,
        workoutStore: AppContainer().workoutStore,
        exerciseStore: AppContainer().exerciseStore,
        workoutId: "preview",
        onDismiss: {}
    )
}
