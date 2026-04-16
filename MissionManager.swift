//
//  MissionManager.swift
//  ZAMKE
//
//  3단계 미션 시스템
//
//  미션 1: 저승의 시선 (시선 밀어내기)
//  미션 2: 주시 (눈 마주치면 죽는다)
//  미션 3: 문장 완성 (긍정 문장 블럭 배열)
//
//  근본 원칙: @Published 변경을 최소화하여 SwiftUI 렌더링 충돌 방지
//  전환 시 단 1회의 objectWillChange만 발생하도록 설계
//

import SwiftUI
import Combine

// MARK: - 미션 타입

enum MissionType: Int, CaseIterable {
    case reaperGaze   = 0  // 저승의 시선
    case redLight     = 1  // 눈 마주치면 죽는다 (기존 3번 → 2번)
    case sentence     = 2  // 문장 완성 (새 미션, 기존 패턴 대체)
    case breath       = 3  // 숨소리 탐지 (비활성)
    case wisp         = 4  // 도깨비불 포획 (비활성)

    var displayName: String {
        switch self {
        case .reaperGaze:   return "시선"
        case .redLight:     return "주시"
        case .sentence:     return "각성"
        case .breath:       return "숨소리"
        case .wisp:         return "포획"
        }
    }

    var instruction: String {
        switch self {
        case .reaperGaze:   return "밀어내라"
        case .redLight:     return "피해라"
        case .sentence:     return "완성하라"
        case .breath:       return "숨을 참아라"
        case .wisp:         return "기울여라"
        }
    }

    /// 현재 활성 미션 수 (1~3: 시선, 주시, 문장완성)
    static var activeMissionCount: Int { 3 }

    var next: MissionType? {
        let n = MissionType(rawValue: rawValue + 1)
        // activeMissionCount 까지만 진행
        guard let next = n, next.rawValue < Self.activeMissionCount else { return nil }
        return next
    }

    static var totalCount: Int { activeMissionCount }
}

// MARK: - 미션 결과

enum MissionResult {
    case success
    case failure
}

// MARK: - MissionManager

final class MissionManager: ObservableObject {

    // ⚠️ 수동 objectWillChange — @Published 다중 업데이트로 인한 렌더링 충돌 방지
    var currentMission: MissionType = .reaperGaze
    var missionActive: Bool = false
    var failCount: Int = 0
    var totalCleared: Int = 0
    var isCompleted: Bool = false
    var missionAttemptID: UUID = UUID()

    private var transitionTimer: Timer?

    var difficulty: Double {
        min(1.0 + Double(failCount) * 0.3, 3.0)
    }

    func startMission() {
        currentMission = .reaperGaze
        missionActive = true
        failCount = 0
        totalCleared = 0
        isCompleted = false
        missionAttemptID = UUID()
        objectWillChange.send()
    }

    func reportResult(_ result: MissionResult) {
        switch result {
        case .success:
            totalCleared += 1
            if let next = currentMission.next {
                // 1초 후 다음 미션으로 전환 — 단 1회 objectWillChange
                transitionTimer?.invalidate()
                let t = Timer(timeInterval: 1.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.currentMission = next
                    self.missionAttemptID = UUID()
                    self.objectWillChange.send()
                }
                RunLoop.main.add(t, forMode: .common)
                transitionTimer = t
            } else {
                isCompleted = true
                missionActive = false
                objectWillChange.send()
            }

        case .failure:
            failCount += 1
            missionAttemptID = UUID()
            objectWillChange.send()
        }
    }
}
