//
//  HwadeuljjakRecordStore.swift
//  ZAMKE
//
//  화들짝 모드 사용 기록 — 날짜별 성공/실패, 지속 시간, 스트릭
//

import Foundation
import Observation

// MARK: - 기록 모델

struct HwadeuljjakRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval   // 초
    let success: Bool
    let failCount: Int

    init(date: Date = Date(), duration: TimeInterval, success: Bool, failCount: Int) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.success = success
        self.failCount = failCount
    }
}

// MARK: - 기록 저장소

@Observable
class HwadeuljjakRecordStore {
    static let shared = HwadeuljjakRecordStore()

    var records: [HwadeuljjakRecord] = []

    @ObservationIgnored
    private let key = "zamke_hwadeuljjak_records"

    private init() { load() }

    // ── 기록 추가 ──

    func add(duration: TimeInterval, success: Bool, failCount: Int) {
        let record = HwadeuljjakRecord(
            duration: duration,
            success: success,
            failCount: failCount
        )
        records.insert(record, at: 0)  // 최신 먼저
        save()
    }

    // ── 통계 ──

    var totalAttempts: Int { records.count }

    var totalSuccess: Int {
        records.filter { $0.success }.count
    }

    var totalFail: Int {
        records.filter { !$0.success }.count
    }

    /// 연속 성공 일수 (스트릭)
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        let todayRecords = records.filter {
            cal.isDate($0.date, inSameDayAs: checkDate) && $0.success
        }

        if todayRecords.isEmpty {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let dayHasSuccess = records.contains {
                cal.isDate($0.date, inSameDayAs: checkDate) && $0.success
            }

            if dayHasSuccess {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        return streak
    }

    /// 최장 연속 성공 일수
    var bestStreak: Int {
        let cal = Calendar.current
        var successDays = Set<DateComponents>()
        for r in records where r.success {
            let comps = cal.dateComponents([.year, .month, .day], from: r.date)
            successDays.insert(comps)
        }

        guard !successDays.isEmpty else { return 0 }

        let sortedDates = successDays.compactMap { cal.date(from: $0) }.sorted()
        var best = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = cal.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else if diff > 1 {
                current = 1
            }
        }

        return best
    }

    /// 최근 N일 기록
    func recordsForLast(_ days: Int) -> [HwadeuljjakRecord] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return records
        }
        return records.filter { $0.date >= cutoff }
    }

    /// 최근 N일 성공률
    func successRate(days: Int) -> Double {
        let recent = recordsForLast(days)
        guard !recent.isEmpty else { return 0 }
        let successes = recent.filter { $0.success }.count
        return Double(successes) / Double(recent.count)
    }

    /// 평균 지속 시간 (성공 기록만)
    var avgSuccessDuration: TimeInterval {
        let successes = records.filter { $0.success }
        guard !successes.isEmpty else { return 0 }
        return successes.reduce(0) { $0 + $1.duration } / Double(successes.count)
    }

    // ── 영속성 ──

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HwadeuljjakRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
