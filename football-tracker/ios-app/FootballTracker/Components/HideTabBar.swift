import SwiftUI
import UIKit

/// Hides the tab bar when the view appears and restores it when disappearing.
/// Uses direct UITabBar manipulation with performWithoutAnimation for instant transitions.
struct HideTabBarModifier: ViewModifier {
    @State private var tabBar: UITabBar?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let tb = findTabBar() {
                    tabBar = tb
                    UIView.performWithoutAnimation {
                        tb.isHidden = true
                        // Also move it off screen to prevent layout gaps
                        tb.frame.origin.y = UIScreen.main.bounds.height
                    }
                }
            }
            .onDisappear {
                if let tb = tabBar {
                    UIView.performWithoutAnimation {
                        tb.isHidden = false
                        // Restore position
                        tb.superview?.setNeedsLayout()
                        tb.superview?.layoutIfNeeded()
                    }
                }
            }
    }

    private func findTabBar() -> UITabBar? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return findTabBar(in: window)
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        for subview in view.subviews {
            if let found = findTabBar(in: subview) {
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
