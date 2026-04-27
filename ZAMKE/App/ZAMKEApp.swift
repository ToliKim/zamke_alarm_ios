//
//  ZAMKEApp.swift
//  ZAMKE
//
//  Created by 김남국 on 4/8/26.
//

import SwiftUI
import UserNotifications

// ── 스누즈 상태 관리 (앱 전역) ──
@MainActor
@Observable
final class SnoozeManager {
    static let shared = SnoozeManager()
    var shouldLaunchHwadeuljjak = false
    private init() {}
}

// ── 알림 델리게이트 ──
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // 포그라운드에서도 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if userInfo["isSnooze"] as? Bool == true {
            // 스누즈 알림 → 화들짝 실행
            Task { @MainActor in
                SnoozeManager.shared.shouldLaunchHwadeuljjak = true
            }
            completionHandler([.sound])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    // 알림 액션 처리 (사용자가 "10분만 더" 버튼을 누른 경우)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        if actionID == AlarmStore.snoozeActionID {
            // 스누즈 액션 → 10분 후 알림 예약
            AlarmStore().scheduleSnoozeNotification()
        } else if actionID == UNNotificationDefaultActionIdentifier {
            // 알림 자체를 탭한 경우
            if userInfo["isSnooze"] as? Bool == true {
                // 스누즈 알림 탭 → 화들짝 실행
                Task { @MainActor in
                    SnoozeManager.shared.shouldLaunchHwadeuljjak = true
                }
            }
        }

        completionHandler()
    }
}

@main
struct ZAMKEApp: App {
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
