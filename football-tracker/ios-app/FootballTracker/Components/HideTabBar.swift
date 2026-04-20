import SwiftUI
import UIKit

/// Hides the tab bar without animation when this view appears,
/// and restores it without animation when this view disappears.
struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                setTabBarHidden(true)
            }
            .onDisappear {
                setTabBarHidden(false)
            }
    }

    private func setTabBarHidden(_ hidden: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBar = window.rootViewController?.findTabBarController()?.tabBar else {
            return
        }
        // Set without animation
        UIView.performWithoutAnimation {
            tabBar.isHidden = hidden
            tabBar.superview?.setNeedsLayout()
            tabBar.superview?.layoutIfNeeded()
        }
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tabBar = self as? UITabBarController {
            return tabBar
        }
        for child in children {
            if let found = child.findTabBarController() {
                return found
            }
        }
        return nil
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}
