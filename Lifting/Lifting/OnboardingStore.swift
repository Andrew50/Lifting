//
//  OnboardingStore.swift
//  Lifting
//

import Foundation
import Combine

enum FitnessGoal: String, CaseIterable, Codable {
    case buildMuscle = "build_muscle"
    case getStronger = "get_stronger"
    case loseWeight = "lose_weight"
    case maintain = "maintain"

    var title: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .getStronger: return "Get Stronger"
        case .loseWeight: return "Lose Weight"
        case .maintain: return "Maintain"
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle: return "Maximize hypertrophy and size"
        case .getStronger: return "Increase strength and 1RM"
        case .loseWeight: return "Lose fat while preserving muscle"
        case .maintain: return "Stay consistent and healthy"
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .getStronger: return "bolt.fill"
        case .loseWeight: return "flame.fill"
        case .maintain: return "checkmark.seal.fill"
        }
    }
}

enum TrainingAge: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Less than 1 year"
        case .intermediate: return "1 to 3 years"
        case .advanced: return "3+ years"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
}

enum WeeklyFrequency: String, CaseIterable, Codable {
    case low = "2_3"
    case medium = "4_5"
    case high = "6_plus"

    var title: String {
        switch self {
        case .low: return "2 – 3 days"
        case .medium: return "4 – 5 days"
        case .high: return "6+ days"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Casual or busy schedule"
        case .medium: return "Dedicated training"
        case .high: return "High frequency athlete"
        }
    }

    var icon: String {
        switch self {
        case .low: return "calendar"
        case .medium: return "calendar.badge.plus"
        case .high: return "calendar.badge.exclamationmark"
        }
    }
}

@MainActor
final class OnboardingStore: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var fitnessGoal: FitnessGoal?
    @Published var trainingAge: TrainingAge?
    @Published var weeklyFrequency: WeeklyFrequency?

    private let defaults = UserDefaults.standard

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: "onboarding.completed")
        if let raw = defaults.string(forKey: "onboarding.goal") {
            fitnessGoal = FitnessGoal(rawValue: raw)
        }
        if let raw = defaults.string(forKey: "onboarding.trainingAge") {
            trainingAge = TrainingAge(rawValue: raw)
        }
        if let raw = defaults.string(forKey: "onboarding.frequency") {
            weeklyFrequency = WeeklyFrequency(rawValue: raw)
        }
    }

    func saveAnswers(
        goal: FitnessGoal,
        trainingAge: TrainingAge,
        frequency: WeeklyFrequency
    ) {
        self.fitnessGoal = goal
        self.trainingAge = trainingAge
        self.weeklyFrequency = frequency

        defaults.set(goal.rawValue, forKey: "onboarding.goal")
        defaults.set(trainingAge.rawValue, forKey: "onboarding.trainingAge")
        defaults.set(frequency.rawValue, forKey: "onboarding.frequency")
    }

    func completeOnboarding(
        goal: FitnessGoal,
        trainingAge: TrainingAge,
        frequency: WeeklyFrequency
    ) {
        self.fitnessGoal = goal
        self.trainingAge = trainingAge
        self.weeklyFrequency = frequency
        self.hasCompletedOnboarding = true

        defaults.set(goal.rawValue, forKey: "onboarding.goal")
        defaults.set(trainingAge.rawValue, forKey: "onboarding.trainingAge")
        defaults.set(frequency.rawValue, forKey: "onboarding.frequency")
        defaults.set(true, forKey: "onboarding.completed")
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        fitnessGoal = nil
        trainingAge = nil
        weeklyFrequency = nil
        defaults.removeObject(forKey: "onboarding.completed")
        defaults.removeObject(forKey: "onboarding.goal")
        defaults.removeObject(forKey: "onboarding.trainingAge")
        defaults.removeObject(forKey: "onboarding.frequency")
    }
}
