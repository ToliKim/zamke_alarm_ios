//
//  ReportView.swift
//  ZAMKE
//
//  리포트 — 화들짝 모드 사용 기록
//  어두운 배경 위 흐릿한 카드, 성공은 은은한 빛, 실패는 붉은 톤
//

import SwiftUI

struct ReportView: View {
    var onBack: () -> Void

    private var store: HwadeuljjakRecordStore { HwadeuljjakRecordStore.shared }
    @State private var showDays: Int = 7       // 7 또는 30
    @State private var appeared = false

    // 푸른빛 흰색
    private let textColor = Color(red: 0.82, green: 0.86, blue: 0.96)
    private let dimText = Color(red: 0.55, green: 0.58, blue: 0.68)
    private let successColor = Color(red: 0.3, green: 0.85, blue: 0.55)
    private let failColor = Color(red: 0.95, green: 0.25, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 미세한 비네트
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.5)],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // ── 통계 카드 ──
                        statsSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)
                            .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

                        // ── 기간 선택 ──
                        periodSelector
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                        // ── 기록 리스트 ──
                        recordsList
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: appeared)

                        Spacer().frame(height: 50)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                appeared = true
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 헤더
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var headerBar: some View {
        HStack {
            Button {
                onBack()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("홈")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(dimText)
            }

            Spacer()

            Text("리포트")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(textColor)

            Spacer()

            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 통계 카드
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var statsSection: some View {
        VStack(spacing: 12) {
            // 상단 2칸
            HStack(spacing: 12) {
                statCard(
                    title: "연속 성공",
                    value: "\(store.currentStreak)",
                    unit: "일",
                    accent: store.currentStreak > 0 ? successColor : dimText
                )

                statCard(
                    title: "최장 연속",
                    value: "\(store.bestStreak)",
                    unit: "일",
                    accent: store.bestStreak > 0 ? successColor.opacity(0.7) : dimText
                )
            }

            // 하단 3칸
            HStack(spacing: 12) {
                statCard(
                    title: "총 성공",
                    value: "\(store.totalSuccess)",
                    unit: "회",
                    accent: successColor.opacity(0.6)
                )

                statCard(
                    title: "총 시도",
                    value: "\(store.totalAttempts)",
                    unit: "회",
                    accent: dimText
                )

                statCard(
                    title: "평균 시간",
                    value: formatDuration(store.avgSuccessDuration),
                    unit: "",
                    accent: dimText
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, unit: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundColor(dimText)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accent.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.1), lineWidth: 1)
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 기간 선택
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var periodSelector: some View {
        HStack(spacing: 0) {
            periodTab("7일", days: 7)
            periodTab("30일", days: 30)
            periodTab("전체", days: 9999)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.horizontal, 16)
    }

    private func periodTab(_ label: String, days: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDays = days
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: showDays == days ? .bold : .medium))
                .foregroundColor(showDays == days ? textColor : dimText.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    showDays == days
                    ? RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                    : nil
                )
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 기록 리스트
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var recordsList: some View {
        let filtered = showDays >= 9999
            ? store.records
            : store.recordsForLast(showDays)

        return VStack(spacing: 10) {
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Text("기록 없음")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(dimText.opacity(0.4))
                    Text("화들짝 모드를 실행하면\n기록이 여기에 표시됩니다")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(dimText.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // 날짜별 그룹
                let grouped = groupByDate(filtered)

                ForEach(grouped, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // 날짜 헤더
                        Text(formatDateHeader(group.date))
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(dimText.opacity(0.4))
                            .padding(.leading, 4)

                        ForEach(group.records) { record in
                            recordCard(record)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func recordCard(_ record: HwadeuljjakRecord) -> some View {
        HStack(spacing: 14) {
            // 상태 아이콘
            Circle()
                .fill(record.success
                      ? successColor.opacity(0.2)
                      : failColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: record.success ? "checkmark" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(record.success
                                         ? successColor : failColor.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(formatTime(record.date))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.85))

                HStack(spacing: 8) {
                    Text(formatDuration(record.duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(dimText.opacity(0.5))

                    if record.failCount > 0 {
                        Text("실패 \(record.failCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(failColor.opacity(0.5))
                    }
                }
            }

            Spacer()

            Text(record.success ? "성공" : "실패")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(record.success ? successColor : failColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(record.success
                              ? successColor.opacity(0.08)
                              : failColor.opacity(0.08))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    record.success
                    ? successColor.opacity(0.06)
                    : failColor.opacity(0.06),
                    lineWidth: 1
                )
        )
        // 성공: 은은한 빛 / 실패: 붉은 톤
        .shadow(
            color: record.success
                ? successColor.opacity(0.04)
                : failColor.opacity(0.03),
            radius: 12
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 포맷터
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 {
            return "\(m)분 \(s)초"
        }
        return "\(s)초"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDateHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "오늘"
        } else if cal.isDateInYesterday(date) {
            return "어제"
        } else {
            let f = DateFormatter()
            f.dateFormat = "M월 d일 (E)"
            f.locale = Locale(identifier: "ko_KR")
            return f.string(from: date)
        }
    }

    // ── 날짜별 그룹핑 ──

    private struct DateGroup {
        let date: Date
        let records: [HwadeuljjakRecord]
    }

    private func groupByDate(_ records: [HwadeuljjakRecord]) -> [DateGroup] {
        let cal = Calendar.current
        var dict: [DateComponents: [HwadeuljjakRecord]] = [:]

        for r in records {
            let comps = cal.dateComponents([.year, .month, .day], from: r.date)
            dict[comps, default: []].append(r)
        }

        return dict.map { (comps, recs) in
            DateGroup(date: cal.date(from: comps) ?? Date(), records: recs)
        }
        .sorted { $0.date > $1.date }
    }
}
