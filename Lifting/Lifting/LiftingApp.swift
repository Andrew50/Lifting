//
//  LiftingApp.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI
import UIKit
import UserNotifications

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

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                container: container,
                authStore: container.authStore,
                onboardingStore: container.onboardingStore,
                tabNav: container.tabNavigationCoordinator
            )
        }
    }
}
