//
//  MissionManager.swift
//  ZAMKE
//
//  3단계 미션 시스템
//  저승의 시선 → 주시 → 각성
//

import SwiftUI
import Observation

// MARK: - 미션 타입

enum MissionType: Int, CaseIterable {
    case reaperGaze = 0  // 1단계: 저승의 시선 — 눈을 밀어내라
    case redLight   = 1  // 2단계: 주시 — 눈 마주치면 죽는다
    case sentence   = 2  // 3단계: 각성 — 문장 완성

    static var totalCount: Int { allCases.count }

    var displayName: String {
        switch self {
        case .reaperGaze: return "시선"
        case .redLight:   return "주시"
        case .sentence:   return "각성"
        }
    }

    var instruction: String {
        switch self {
        case .reaperGaze: return "눈 을  밀 어 내 라"
        case .redLight:   return "눈  마 주 치 면  죽 는 다"
        case .sentence:   return "문 장 을  완 성 하 라"
        }
    }

    var next: MissionType? {
        MissionType(rawValue: rawValue + 1)
    }
}

// MARK: - 미션 결과

enum MissionResult {
    case success
    case failure
}

// MARK: - MissionManager

@Observable
final class MissionManager {

    var currentMission: MissionType = .reaperGaze
    var missionActive: Bool = false
    var failCount: Int = 0
    var totalCleared: Int = 0
    var isCompleted: Bool = false
    var missionAttemptID: UUID = UUID()

    @ObservationIgnored
    var onMissionSuccess: (() -> Void)?
    @ObservationIgnored
    var onMissionFail: (() -> Void)?
    @ObservationIgnored
    var onAllCleared: (() -> Void)?
    @ObservationIgnored
    var onMissionTransitionEnd: (() -> Void)?   // 전환 완료 직전 콜백

    var difficulty: Double {
        min(1.0 + Double(failCount) * 0.3, 3.0)
    }

    var transitioning: Bool = false

    func startMission() {
        currentMission = .reaperGaze
        missionActive = true
        failCount = 0
        totalCleared = 0
        isCompleted = false
        missionAttemptID = UUID()
    }

    func reportResult(_ result: MissionResult) {
        switch result {
        case .success:
            totalCleared += 1
            if let next = currentMission.next {
                onMissionSuccess?()
                transitioning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                    onMissionTransitionEnd?()   // 다음 미션 시작 전 오디오 정리
                    currentMission = next
                    missionAttemptID = UUID()
                    transitioning = false
                }
            } else {
                isCompleted = true
                missionActive = false
                onAllCleared?()
            }

        case .failure:
            failCount += 1
            missionAttemptID = UUID()
            onMissionFail?()
        }
    }
}
