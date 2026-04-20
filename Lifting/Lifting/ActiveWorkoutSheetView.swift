//
//  ActiveWorkoutSheetView.swift
//  Lifting
//

import SwiftUI
import UserNotifications

struct ActiveWorkoutSheetView: View {
    @ObservedObject var templateStore: TemplateStore
    @ObservedObject var workoutStore: WorkoutStore
    @ObservedObject var exerciseStore: ExerciseStore

    let workoutId: String
    @Binding var selectedDetent: PresentationDetent
    let onDismiss: () -> Void
    /// Called when user drags to collapsed detent; parent dismisses sheet and shows in-app bar.
    var onCollapseToBar: (() -> Void)?

    private static let collapsedDetent = PresentationDetent.height(72)

    @State private var restTimeSeconds: Int = 120
    @State private var showRestTimePicker = false
    @State private var isFinishing = false
    @State private var workoutStartedAt: TimeInterval?
    @State private var showFinishConfirmation = false
    @State private var showCancelConfirmation = false
    @State private var emptySetsCount = 0

    /// Absolute time when the current rest period ends (nil = no active rest).
    @State private var restEndDate: Date?

    private var restCountdownActive: Bool { restEndDate != nil }

    private let restTimeOptions = [30, 45, 60, 90, 120, 180]

    private static let notificationID = "rest-timer-done"

    private func startRestCountdown() {
        let end = Date().addingTimeInterval(Double(restTimeSeconds))
        restEndDate = end
        workoutStore.setActiveRestTimer(workoutId: workoutId, endDate: end)
        scheduleRestNotification(at: end)
    }

    private func stopRestCountdown() {
        restEndDate = nil
        workoutStore.setActiveRestTimer(workoutId: workoutId, endDate: nil)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationID]
        )
    }

    private func remainingSeconds(now: Date) -> Int {
        guard let end = restEndDate else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSince(now))))
    }

    private func scheduleRestNotification(at fireDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        let content = UNMutableNotificationContent()
        content.title = "Rest Over"
        content.body = "Time to start your next set!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    var body: some View {
        fullContent
            .background(Color(UIColor.systemBackground))
            .onAppear {
                if let workout = try? workoutStore.fetchWorkout(workoutId: workoutId) {
                    workoutStartedAt = workout.startedAt
                }
                restTimeSeconds = workoutStore.activeWorkoutRestPresetSeconds
                if workoutStore.activeRestTimerWorkoutId == workoutId,
                   let end = workoutStore.activeRestTimerEndDate,
                   end > Date() {
                    restEndDate = end
                    scheduleRestNotification(at: end)
                }
            }
            .onChange(of: restTimeSeconds) { _, newValue in
                workoutStore.activeWorkoutRestPresetSeconds = newValue
            }
            .onChange(of: selectedDetent) { _, newDetent in
                if newDetent == Self.collapsedDetent {
                    onCollapseToBar?()
                }
            }
    }

    private var fullContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.cancelText)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(AppTheme.cancelBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer()

                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    let now = timeline.date
                    let remaining = remainingSeconds(now: now)
                    let isResting = restEndDate != nil && remaining > 0

                    VStack(spacing: 1) {
                        if isResting {
                            Text("Rest")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(remaining.formattedAsMinutesSeconds)
                                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                                .foregroundStyle(AppTheme.accent)
                        } else {
                            Text("Elapsed")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(TimeInterval.elapsed(since: workoutStartedAt))
                                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .onChange(of: isResting) { wasResting, nowResting in
                        if wasResting && !nowResting {
                            stopRestCountdown()
                        }
                    }
                }

                Spacer()

                Button {
                    emptySetsCount = (try? workoutStore.countEmptySets(workoutId: workoutId)) ?? 0
                    showFinishConfirmation = true
                } label: {
                    Text("Finish")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.finishText)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(AppTheme.finishBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isFinishing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.background)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: restEndDate != nil)
            .alert(
                "Finish Workout?",
                isPresented: $showFinishConfirmation
            ) {
                Button("Finish") {
                    finishWorkout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if emptySetsCount > 0 {
                    Text(
                        "Are you sure you want to finish? \(emptySetsCount) empty \(emptySetsCount == 1 ? "set" : "sets") will be discarded."
                    )
                } else {
                    Text("Are you sure you want to finish this workout?")
                }
            }
            .alert(
                "Cancel Workout?",
                isPresented: $showCancelConfirmation
            ) {
                Button("Cancel Workout", role: .destructive) {
                    cancelWorkout()
                }
                Button("Keep Working", role: .cancel) {}
            } message: {
                Text(
                    "Are you sure you want to cancel this workout? All progress will be lost."
                )
            }

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
                    restTimeSeconds: $restTimeSeconds,
                    onSetCompleted: {
                        startRestCountdown()
                    }
                )
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
        stopRestCountdown()
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

    private func cancelWorkout() {
        stopRestCountdown()
        do {
            try workoutStore.discardPendingWorkout(workoutId: workoutId)
        } catch {}
        onDismiss()
    }
}

#Preview {
    ActiveWorkoutSheetView(
        templateStore: AppContainer().templateStore,
        workoutStore: AppContainer().workoutStore,
        exerciseStore: AppContainer().exerciseStore,
        workoutId: "preview",
        selectedDetent: .constant(.large),
        onDismiss: {},
        onCollapseToBar: nil
    )
}
