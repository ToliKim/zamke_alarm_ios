//
//  ReportView.swift
//  ZAMKE
//
//  화들짝 리포트 — 성공/루저 기록 확인
//

import SwiftUI

struct ReportView: View {

    var onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    private var store: HwadeuljjakRecordStore { HwadeuljjakRecordStore.shared }

    @State private var selectedPeriod: Period = .all
    @State private var showResetConfirm = false

    enum Period: String, CaseIterable {
        case week = "7일"
        case month = "30일"
        case all = "전체"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    private var filteredRecords: [HwadeuljjakRecord] {
        if let days = selectedPeriod.days {
            return store.recordsForLast(days: days)
        }
        return store.records
    }

    private var filteredSuccess: Int {
        filteredRecords.filter { $0.success }.count
    }

    private var filteredLoser: Int {
        filteredRecords.filter { !$0.success }.count
    }

    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.059, blue: 0.102)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── 헤더 ──
                HStack {
                    Button { onBack?() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("홈")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    Text("리포트")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.92))

                    Spacer()

                    Color.clear.frame(width: 50, height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 20) {

                        // ── 통계 카드 ──
                        statsSection

                        // ── 기간 선택 ──
                        periodPicker

                        // ── 성공 / 루저 요약 ──
                        summaryRow

                        // ── 연속 기록 ──
                        streakSection

                        // ── 기록 리스트 ──
                        recordsList

                        // ── 리셋 버튼 ──
                        resetButton
                            .padding(.top, 20)

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .alert("기록 초기화", isPresented: $showResetConfirm) {
            Button("초기화", role: .destructive) {
                store.resetAll()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("모든 기록이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "총 시도",
                value: "\(store.totalAttempts)",
                color: .white
            )
            statCard(
                title: "성공",
                value: "\(store.totalSuccess)",
                color: .green
            )
            statCard(
                title: "루저",
                value: "\(store.totalLoser)",
                color: .red
            )
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.85))

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 13, weight: selectedPeriod == period ? .semibold : .regular))
                        .foregroundColor(
                            selectedPeriod == period
                            ? .white.opacity(0.9)
                            : .white.opacity(0.35)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedPeriod == period
                            ? Color.white.opacity(0.08)
                            : Color.clear
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 16) {
            // 성공률
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", store.successRate()))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                Text("성공률")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.04))
            )

            // 기간 내 성공
            VStack(spacing: 4) {
                Text("\(filteredSuccess)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                Text("성공")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )

            // 기간 내 루저
            VStack(spacing: 4) {
                Text("\(filteredLoser)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.7))
                Text("루저")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.04))
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(store.currentStreak)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.8))
                Text("현재 연속 성공")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.04))
            )

            VStack(spacing: 4) {
                Text("\(store.bestStreak)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
                Text("최고 연속 성공")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.04))
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Records List

    private var recordsList: some View {
        VStack(spacing: 0) {
            // 섹션 헤더
            HStack {
                Text("기록")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if filteredRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.15))
                    Text("아직 기록이 없습니다")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.vertical, 40)
            } else {
                let grouped = groupFilteredByDate()
                ForEach(grouped, id: \.date) { group in
                    VStack(spacing: 0) {
                        // 날짜 헤더
                        HStack {
                            Text(group.date)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 6)

                        ForEach(group.records) { record in
                            recordRow(record)
                        }
                    }
                }
            }
        }
    }

    private func groupFilteredByDate() -> [(date: String, records: [HwadeuljjakRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"

        var dict: [String: [HwadeuljjakRecord]] = [:]
        var order: [String] = []

        for record in filteredRecords {
            let key = formatter.string(from: record.date)
            if dict[key] == nil {
                dict[key] = []
                order.append(key)
            }
            dict[key]?.append(record)
        }

        return order.map { (date: $0, records: dict[$0] ?? []) }
    }

    private func recordRow(_ record: HwadeuljjakRecord) -> some View {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let minutes = Int(record.duration) / 60
        let seconds = Int(record.duration) % 60
        let durationText = minutes > 0
            ? "\(minutes)분 \(seconds)초"
            : "\(seconds)초"

        return HStack(spacing: 14) {
            // 결과 아이콘
            ZStack {
                Circle()
                    .fill(record.success
                          ? Color.green.opacity(0.15)
                          : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: record.success ? "checkmark" : "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(record.success
                                    ? .green.opacity(0.8)
                                    : .red.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.success ? "성공" : "루저")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(record.success
                                    ? .green.opacity(0.8)
                                    : .red.opacity(0.8))

                HStack(spacing: 8) {
                    Text(timeFormatter.string(from: record.date))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))

                    Text(durationText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.25))

                    if record.failCount > 0 {
                        Text("실패 \(record.failCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red.opacity(0.4))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            showResetConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text("전체 기록 초기화")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.red.opacity(0.7))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
}
