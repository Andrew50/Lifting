//
//  DisplayPreferences.swift
//  Lifting
//
//  Per-exercise display preferences for weight unit (kg/lbs) and intensity (RIR/RPE).
//  Stored in UserDefaults; app-wide keys used as fallback for exercises with no saved preference.
//

import Foundation

enum DisplayPreferences {
    private static let appWideWeightKey = "displayWeightUnit"
    private static let appWideIntensityKey = "displayIntensityDisplay"

    static func displayWeightUnit(for exerciseId: String) -> String {
        UserDefaults.standard.string(forKey: "exercise_\(exerciseId)_weightUnit")
            ?? UserDefaults.standard.string(forKey: appWideWeightKey)
            ?? "lbs"
    }

    static func displayIntensityDisplay(for exerciseId: String) -> String {
        UserDefaults.standard.string(forKey: "exercise_\(exerciseId)_intensityDisplay")
            ?? UserDefaults.standard.string(forKey: appWideIntensityKey)
            ?? "rpe"
    }

    /// Set weight unit for the given exercise and update app-wide default.
    static func setWeightUnit(_ unit: String, for exerciseId: String) {
        UserDefaults.standard.set(unit, forKey: "exercise_\(exerciseId)_weightUnit")
        UserDefaults.standard.set(unit, forKey: appWideWeightKey)
    }

    /// Set intensity display for the given exercise and update app-wide default.
    static func setIntensityDisplay(_ display: String, for exerciseId: String) {
        UserDefaults.standard.set(display, forKey: "exercise_\(exerciseId)_intensityDisplay")
        UserDefaults.standard.set(display, forKey: appWideIntensityKey)
    }

    /// Set weight unit for all given exercise IDs and app-wide default.
    static func setWeightUnit(_ unit: String, forExerciseIds exerciseIds: [String]) {
        for id in exerciseIds {
            UserDefaults.standard.set(unit, forKey: "exercise_\(id)_weightUnit")
        }
        UserDefaults.standard.set(unit, forKey: appWideWeightKey)
    }

    /// Set intensity display for all given exercise IDs and app-wide default.
    static func setIntensityDisplay(_ display: String, forExerciseIds exerciseIds: [String]) {
        for id in exerciseIds {
            UserDefaults.standard.set(display, forKey: "exercise_\(id)_intensityDisplay")
        }
        UserDefaults.standard.set(display, forKey: appWideIntensityKey)
    }
}
