import UIKit

enum SubHelpHaptics {
    static let userDefaultsKey = "subhelp.hapticsEnabled"

    /// `true` when the key is unset (existing installs) or explicitly enabled.
    private static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: userDefaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        return true
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
