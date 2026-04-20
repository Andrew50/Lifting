//
//  TabNavigationCoordinator.swift
//  Lifting
//

import Combine
import Foundation

enum AppTab: String, Hashable {
    case workout
    case progress
    case exercises
    case profile
}

@MainActor
final class TabNavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .workout
    @Published var pendingProgressSegment: ProgressSegment? = nil

    /// Switch to the Progress tab with a specific segment pre-selected.
    func navigateToProgress(segment: ProgressSegment) {
        pendingProgressSegment = segment
        selectedTab = .progress
    }

    /// Called by ProgressView after it consumes the pending segment.
    func clearPendingSegment() {
        pendingProgressSegment = nil
    }
}
