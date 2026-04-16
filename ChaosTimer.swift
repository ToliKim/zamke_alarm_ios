//
//  ChaosTimer.swift
//  ZAMKE
//
//  예측 불가능 타이밍 생성기
//

import Foundation

final class ChaosTimer {
    private var recentIntervals: [Double] = []
    private let historySize = 5
    private var chaosLevel: Double = 0.0

    func nextInterval(in range: ClosedRange<Double>, intensity: Double = 0) -> Double {
        var interval = Double.random(in: range)
        let intensityFactor = 1.0 - (intensity * 0.4)
        interval *= intensityFactor
        interval = antiPattern(interval, range: range)

        if Double.random(in: 0...1) < 0.12 {
            interval = Bool.random()
                ? range.lowerBound * 0.5
                : range.upperBound * 1.3
        }

        let jitter = Double.random(in: -0.15...0.15)
        interval *= (1.0 + jitter)
        interval = max(0.3, min(interval, range.upperBound * 2.0))

        recentIntervals.append(interval)
        if recentIntervals.count > historySize { recentIntervals.removeFirst() }
        return interval
    }

    func increaseChaos(by amount: Double = 0.05) {
        chaosLevel = min(chaosLevel + amount, 1.0)
    }

    func reset() {
        recentIntervals.removeAll()
        chaosLevel = 0
    }

    private func antiPattern(_ proposed: Double, range: ClosedRange<Double>) -> Double {
        guard !recentIntervals.isEmpty else { return proposed }
        let avg = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
        let similarity = abs(proposed - avg) / max(avg, 0.1)
        if similarity < 0.2 {
            let direction: Double = proposed > avg ? 1.0 : -1.0
            let push = Double.random(in: 0.3...0.6) * (range.upperBound - range.lowerBound)
            return max(range.lowerBound, min(proposed + direction * push, range.upperBound))
        }
        return proposed
    }
}
