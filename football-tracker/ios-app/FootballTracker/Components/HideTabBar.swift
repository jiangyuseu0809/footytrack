import SwiftUI
import UIKit

/// Hides the tab bar instantly (no animation) when this view appears,
/// and restores it instantly when this view disappears.
/// Uses a UIKit lifecycle hook to avoid SwiftUI's animated toolbar transitions.
struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TabBarHider())
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}

private struct TabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> TabBarHiderController {
        TabBarHiderController()
    }

    func updateUIViewController(_ uiViewController: TabBarHiderController, context: Context) {}
}

private class TabBarHiderController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTabBarHidden(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTabBarHidden(false)
    }

    private func setTabBarHidden(_ hidden: Bool) {
        guard let tabBar = tabBarController?.tabBar else { return }
        guard tabBar.isHidden != hidden else { return }
        UIView.performWithoutAnimation {
            tabBar.isHidden = hidden
            tabBar.superview?.setNeedsLayout()
            tabBar.superview?.layoutIfNeeded()
        }
    }
}
