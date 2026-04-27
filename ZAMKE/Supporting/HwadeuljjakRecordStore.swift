//
//  HwadeuljjakRecordStore.swift
//  ZAMKE
//
//  화들짝 기록 저장소
//  성공/루저 기록을 UserDefaults에 저장
//

import Foundation
import Observation

// MARK: - 기록 모델

struct HwadeuljjakRecord: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let duration: TimeInterval   // 소요 시간 (초)
    let success: Bool            // true = 성공, false = 루저(포기)
    let failCount: Int           // 미션 중 실패 횟수
}

// MARK: - 저장소

@Observable
final class HwadeuljjakRecordStore {

    static let shared = HwadeuljjakRecordStore()

    var records: [HwadeuljjakRecord] = []

    @ObservationIgnored
    private let key = "zamke_hwadeuljjak_records"

    private init() {
        load()
    }

    // MARK: - 추가

    func add(duration: TimeInterval, success: Bool, failCount: Int) {
        let record = HwadeuljjakRecord(
            date: Date(),
            duration: duration,
            success: success,
            failCount: failCount
        )
        records.insert(record, at: 0)
        save()
    }

    // MARK: - 통계

    var totalAttempts: Int { records.count }

    var totalSuccess: Int { records.filter { $0.success }.count }

    var totalLoser: Int { records.filter { !$0.success }.count }

    var currentStreak: Int {
        var streak = 0
        for r in records {
            if r.success { streak += 1 }
            else { break }
        }
        return streak
    }

    var bestStreak: Int {
        var best = 0
        var current = 0
        for r in records {
            if r.success {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    func successRate() -> Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalSuccess) / Double(totalAttempts) * 100
    }

    /// 최근 N일 기록
    func recordsForLast(days: Int) -> [HwadeuljjakRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.date >= cutoff }
    }

    /// 날짜별 그룹핑 (최신순)
    func groupedByDate() -> [(date: String, records: [HwadeuljjakRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"

        var dict: [String: [HwadeuljjakRecord]] = [:]
        var order: [String] = []

        for record in records {
            let key = formatter.string(from: record.date)
            if dict[key] == nil {
                dict[key] = []
                order.append(key)
            }
            dict[key]?.append(record)
        }

        return order.map { (date: $0, records: dict[$0] ?? []) }
    }

    // MARK: - 리셋

    func resetAll() {
        records = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HwadeuljjakRecord].self, from: data)
        else { return }
        records = decoded
    }
}
