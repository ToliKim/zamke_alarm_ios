//
//  ZamkeAudioState.swift
//  ZAMKE
//
//  긴장 기반 사운드 구조
//
//  1. 드론 — 항상 유지, 존재감 있는 볼륨
//  2. 전조(Omen) — 매우 낮은 볼륨, 짧고 불규칙, 낮은 확률
//  3. 아쟁(Ajaeng) — 희소한 이벤트, 놀람 유발
//
//  핵심: 공포는 "침묵과 간헐적 이벤트"로 만든다
//

import Foundation

enum ZamkePhase: Int, CaseIterable {
    case infiltration = 0
    case presence     = 1
    case cognition    = 2
    case pressure     = 3
    case domination   = 4

    var next: ZamkePhase {
        ZamkePhase(rawValue: rawValue + 1) ?? .domination
    }

    var displayName: String {
        switch self {
        case .infiltration: return "추적 중"
        case .presence:     return "접근 중"
        case .cognition:    return "보고 있다"
        case .pressure:     return "뒤에 있다"
        case .domination:   return "도망쳐라"
        }
    }

    /// 위험 등급 (0.0~1.0)
    var threatLevel: Double {
        Double(rawValue) / 4.0
    }

    /// 위험 색상 — 낮으면 흰색, 높으면 붉은색
    var isDanger: Bool {
        rawValue >= 3
    }
}

struct PhaseParameters {
    // ── 드론 ──
    let droneVolume: Float              // 항상 들릴 정도

    // ── 아쟁 (이벤트: 놀람) ──
    let ajaengEnabled: Bool
    let ajaengMinInterval: Double       // 최소 대기
    let ajaengMaxInterval: Double       // 최대 대기
    let ajaengVolume: ClosedRange<Float>
    let ajaengProbability: Double       // 예약 시점 발사 확률 (10~15%)

    // ── 전조/Omen (기존 Warning → 역할 변경) ──
    let omenEnabled: Bool
    let omenMinInterval: Double
    let omenMaxInterval: Double
    let omenVolume: ClosedRange<Float>  // 매우 낮은 볼륨
    let omenProbability: Double         // 등장 확률 (≤20%)

    // ── 침묵 ──
    let silenceAfterEvent: ClosedRange<Double>   // 이벤트 후 강제 침묵
    let mandatorySilence: ClosedRange<Double>     // 무조건 비는 구간 (5~15초)
}

extension ZamkePhase {
    var parameters: PhaseParameters {
        switch self {

        // ━━ 침투: 거의 드론만. 가끔 전조. 아쟁 매우 드묾 ━━
        case .infiltration:
            return PhaseParameters(
                droneVolume: 0.45,
                ajaengEnabled: true,
                ajaengMinInterval: 25, ajaengMaxInterval: 50,
                ajaengVolume: 0.35...0.45,
                ajaengProbability: 0.10,
                omenEnabled: true,
                omenMinInterval: 12, omenMaxInterval: 25,
                omenVolume: 0.08...0.15,
                omenProbability: 0.12,
                silenceAfterEvent: 8.0...15.0,
                mandatorySilence: 10.0...15.0
            )

        // ━━ 존재: 전조가 가끔 들림. 아쟁 여전히 드묾 ━━
        case .presence:
            return PhaseParameters(
                droneVolume: 0.50,
                ajaengEnabled: true,
                ajaengMinInterval: 20, ajaengMaxInterval: 40,
                ajaengVolume: 0.40...0.55,
                ajaengProbability: 0.12,
                omenEnabled: true,
                omenMinInterval: 10, omenMaxInterval: 20,
                omenVolume: 0.10...0.20,
                omenProbability: 0.15,
                silenceAfterEvent: 7.0...12.0,
                mandatorySilence: 8.0...13.0
            )

        // ━━ 인지: 전조 살짝 증가. 아쟁 가끔 ━━
        case .cognition:
            return PhaseParameters(
                droneVolume: 0.58,
                ajaengEnabled: true,
                ajaengMinInterval: 15, ajaengMaxInterval: 30,
                ajaengVolume: 0.45...0.65,
                ajaengProbability: 0.13,
                omenEnabled: true,
                omenMinInterval: 8, omenMaxInterval: 18,
                omenVolume: 0.12...0.25,
                omenProbability: 0.18,
                silenceAfterEvent: 6.0...10.0,
                mandatorySilence: 7.0...12.0
            )

        // ━━ 압박: 전조 빈도 약간 상승. 아쟁은 여전히 희소 ━━
        case .pressure:
            return PhaseParameters(
                droneVolume: 0.65,
                ajaengEnabled: true,
                ajaengMinInterval: 12, ajaengMaxInterval: 25,
                ajaengVolume: 0.50...0.75,
                ajaengProbability: 0.14,
                omenEnabled: true,
                omenMinInterval: 7, omenMaxInterval: 15,
                omenVolume: 0.15...0.30,
                omenProbability: 0.20,
                silenceAfterEvent: 5.0...8.0,
                mandatorySilence: 6.0...10.0
            )

        // ━━ 장악: 가장 높은 긴장. 아쟁 확률 최대 15% ━━
        case .domination:
            return PhaseParameters(
                droneVolume: 0.72,
                ajaengEnabled: true,
                ajaengMinInterval: 10, ajaengMaxInterval: 20,
                ajaengVolume: 0.55...0.80,
                ajaengProbability: 0.15,
                omenEnabled: true,
                omenMinInterval: 5, omenMaxInterval: 12,
                omenVolume: 0.18...0.35,
                omenProbability: 0.20,
                silenceAfterEvent: 5.0...7.0,
                mandatorySilence: 5.0...8.0
            )
        }
    }

    var durationRange: ClosedRange<Double> {
        switch self {
        case .infiltration: return 20.0...35.0
        case .presence:     return 25.0...40.0
        case .cognition:    return 30.0...50.0
        case .pressure:     return 35.0...60.0
        case .domination:   return 999...999
        }
    }
}
