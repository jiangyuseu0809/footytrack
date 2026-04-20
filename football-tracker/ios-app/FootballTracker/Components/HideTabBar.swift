import SwiftUI
import UIKit

/// Hides the tab bar on detail pages. The tab bar visibility is controlled
/// via SwiftUI's toolbar API, while a UIKit hook disables the animation
/// on the tab bar layer so it appears/disappears instantly.
struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                disableTabBarAnimations()
            }
    }

    private func disableTabBarAnimations() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBar = window.rootViewController?.findTabBarController()?.tabBar else {
            return
        }
        // Disable all CoreAnimation on the tab bar so show/hide is instant
        tabBar.layer.speed = Float.greatestFiniteMagnitude
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
