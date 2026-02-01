//
//  LiftingApp.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

@main
struct LiftingApp: App {
    init() {
        _ = ExerciseDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
