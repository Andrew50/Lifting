//
//  ContentView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    private let preferredWorkoutTabIconName = "figure.strengthtraining.traditional"
    private let fallbackWorkoutTabIconName = "dumbbell"

    private var workoutTabIconName: String {
#if canImport(UIKit)
        if UIImage(systemName: preferredWorkoutTabIconName) != nil {
            return preferredWorkoutTabIconName
        }
        return fallbackWorkoutTabIconName
#else
        return fallbackWorkoutTabIconName
#endif
    }

    var body: some View {
        TabView {
            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: workoutTabIconName)
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
