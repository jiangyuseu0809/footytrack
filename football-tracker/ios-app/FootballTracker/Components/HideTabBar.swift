import SwiftUI
import UIKit

/// View modifier that hides the tab bar instantly (no animation) when a view is pushed.
/// Uses UIKit's native hidesBottomBarWhenPushed which handles the transition without animation.
struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TabBarHider())
    }
}

private struct TabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        TabBarHiderVC()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private class TabBarHiderVC: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Find the hosting controller that's actually pushed in the navigation stack
        // and set hidesBottomBarWhenPushed on it
        if let hosting = findHostingController() {
            hosting.hidesBottomBarWhenPushed = true
            // Force tab bar to hide immediately
            hosting.tabBarController?.tabBar.isHidden = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore tab bar when popping back
        if isMovingFromParent, let hosting = findHostingController() {
            hosting.tabBarController?.tabBar.isHidden = false
        }
    }

    private func findHostingController() -> UIViewController? {
        var vc: UIViewController? = self
        while let current = vc?.parent {
            if current.navigationController != nil {
                return current
            }
            vc = current
        }
        return parent
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}
