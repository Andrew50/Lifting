//
//  TabReselectCoordinator.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Combine
import SwiftUI

@MainActor
final class TabReselectCoordinator: ObservableObject {
    @Published private(set) var historyReselectCount: Int = 0

    func notifyHistoryReselected() {
        historyReselectCount &+= 1
    }
}

#if canImport(UIKit)
import UIKit

/// Observes `UITabBarController` to detect re-tapping the currently-selected tab item.
struct TabBarReselectObserver: UIViewControllerRepresentable {
    @ObservedObject var coordinator: TabReselectCoordinator
    let historyIndex: Int

    func makeUIViewController(context: Context) -> ObserverViewController {
        ObserverViewController(coordinator: coordinator, historyIndex: historyIndex)
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.coordinator = coordinator
        uiViewController.historyIndex = historyIndex
        uiViewController.attachIfNeeded()
    }

    final class ObserverViewController: UIViewController, UITabBarControllerDelegate {
        var coordinator: TabReselectCoordinator
        var historyIndex: Int

        private weak var observedTabBarController: UITabBarController?
        private var lastSelectedIndex: Int?

        init(coordinator: TabReselectCoordinator, historyIndex: Int) {
            self.coordinator = coordinator
            self.historyIndex = historyIndex
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard let tabBarController else { return }
            if observedTabBarController !== tabBarController {
                observedTabBarController = tabBarController
                tabBarController.delegate = self
                lastSelectedIndex = tabBarController.selectedIndex
            }
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            guard
                let viewControllers = tabBarController.viewControllers,
                let newIndex = viewControllers.firstIndex(of: viewController)
            else {
                return true
            }

            if let lastSelectedIndex, newIndex == lastSelectedIndex, newIndex == historyIndex {
                coordinator.notifyHistoryReselected()
            }

            return true
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            guard
                let viewControllers = tabBarController.viewControllers,
                let newIndex = viewControllers.firstIndex(of: viewController)
            else {
                return
            }
            lastSelectedIndex = newIndex
        }
    }
}
#endif

