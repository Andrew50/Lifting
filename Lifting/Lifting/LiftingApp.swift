//
//  LiftingApp.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

@main
struct LiftingApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
