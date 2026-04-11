//
//  LiftingApp.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI
import UIKit

@main
struct LiftingApp: App {
    @StateObject private var container = AppContainer()

    init() {
        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
            .foregroundColor: UIColor(AppTheme.textPrimary),
        ]
        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.textPrimary)
        ]
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().standardAppearance = standard
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
