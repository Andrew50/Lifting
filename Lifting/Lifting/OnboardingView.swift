//
//  OnboardingView.swift
//  Lifting
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    /// Kept for call-site consistency / future use (e.g. personalized copy).
    @ObservedObject var authStore: AuthStore
    let onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var selectedGoal: FitnessGoal? = nil
    @State private var selectedAge: TrainingAge? = nil
    @State private var selectedFrequency: WeeklyFrequency? = nil

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == currentStep ? AppTheme.accent : AppTheme.fieldBorder)
                            .frame(width: i == currentStep ? 24 : 8, height: 8)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 48)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: currentStep)

                Group {
                    switch currentStep {
                    case 0:
                        OnboardingStepView(
                            title: "What's your main goal?",
                            subtitle: "We'll tailor your workouts around this.",
                            items: FitnessGoal.allCases.map {
                                OnboardingItem(id: $0.rawValue, title: $0.title, subtitle: $0.subtitle, icon: $0.icon)
                            },
                            selectedId: selectedGoal?.rawValue,
                            onSelect: { id in selectedGoal = FitnessGoal(rawValue: id) }
                        )
                    case 1:
                        OnboardingStepView(
                            title: "How long have you been lifting?",
                            subtitle: "This helps calibrate your recovery model.",
                            items: TrainingAge.allCases.map {
                                OnboardingItem(id: $0.rawValue, title: $0.title, subtitle: $0.subtitle, icon: $0.icon)
                            },
                            selectedId: selectedAge?.rawValue,
                            onSelect: { id in selectedAge = TrainingAge(rawValue: id) }
                        )
                    case 2:
                        OnboardingStepView(
                            title: "How often do you train?",
                            subtitle: "We'll plan around your schedule.",
                            items: WeeklyFrequency.allCases.map {
                                OnboardingItem(id: $0.rawValue, title: $0.title, subtitle: $0.subtitle, icon: $0.icon)
                            },
                            selectedId: selectedFrequency?.rawValue,
                            onSelect: { id in selectedFrequency = WeeklyFrequency(rawValue: id) }
                        )
                    default:
                        EmptyView()
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if currentStep < 2 {
                            currentStep += 1
                        } else {
                            if let goal = selectedGoal,
                               let age = selectedAge,
                               let freq = selectedFrequency {
                                store.completeOnboarding(
                                    goal: goal,
                                    trainingAge: age,
                                    frequency: freq
                                )
                                onComplete()
                            }
                        }
                    }
                } label: {
                    Text(currentStep < 2 ? "Continue" : "Get Started")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isCurrentStepComplete ? AppTheme.accent : AppTheme.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!isCurrentStepComplete)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentStep -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 32)
                } else {
                    Spacer().frame(height: 52)
                }
            }
        }
    }

    private var isCurrentStepComplete: Bool {
        switch currentStep {
        case 0: return selectedGoal != nil
        case 1: return selectedAge != nil
        case 2: return selectedFrequency != nil
        default: return false
        }
    }
}

struct OnboardingItem {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

struct OnboardingStepView: View {
    let title: String
    let subtitle: String
    let items: [OnboardingItem]
    let selectedId: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            VStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    let isSelected = selectedId == item.id
                    Button {
                        onSelect(item.id)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(isSelected
                                    ? AppTheme.accentLighter
                                    : AppTheme.fieldBackground)
                                .clipShape(RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(item.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.accent)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? AppTheme.accent
                                        : AppTheme.cardBorder,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
