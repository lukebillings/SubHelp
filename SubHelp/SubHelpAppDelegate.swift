import UIKit
import UserNotifications

final class SubHelpAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RenewalNotificationScheduler.registerCategories()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.notification.request.identifier.hasPrefix("subhelp.trial.") else { return }
        let info = response.notification.request.content.userInfo
        guard let idString = info["subscriptionID"] as? String, let id = UUID(uuidString: idString) else { return }
        let decision: TrialDecision
        switch response.actionIdentifier {
        case TrialDecision.keepAction:
            decision = .keep
        case TrialDecision.cancelAction:
            decision = .cancel
        default:
            decision = .ask
        }
        TrialPromptCenter.pending = (id, decision)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: TrialPromptCenter.notification, object: nil)
        }
    }
}
