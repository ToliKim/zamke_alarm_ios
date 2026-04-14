//
//  AlarmView.swift
//  ZAMKE
//
//  알람 모드 — 타이머와 동일한 구조
//  첫 화면에 시간 스크롤 + 깨우는 방식 + 반복 + 저장 버튼
//

import SwiftUI
import Combine
import UserNotifications

// MARK: - Alarm Model

struct AlarmItem: Identifiable, Codable, Equatable {
    let id: UUID
    var hour: Int
    var minute: Int
    var enabled: Bool
    var label: String
    var repeatDays: Set<Int>          // 1=일, 2=월, ... 7=토
    var useMission: Bool
    var wakeStyle: WakeStyleSelection

    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }

    var ampmString: String { hour < 12 ? "AM" : "PM" }

    var hourMinuteString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", h, minute)
    }

    var repeatString: String {
        if repeatDays.isEmpty { return "한 번" }
        if repeatDays.count == 7 { return "매일" }
        let dayNames = ["", "일", "월", "화", "수", "목", "금", "토"]
        let sorted = repeatDays.sorted()
        if sorted == [2, 3, 4, 5, 6] { return "평일" }
        if sorted == [1, 7] { return "주말" }
        return sorted.map { dayNames[$0] }.joined(separator: " ")
    }

    static func new() -> AlarmItem {
        let cal = Calendar.current
        let now = Date()
        return AlarmItem(
            id: UUID(),
            hour: cal.component(.hour, from: now),
            minute: cal.component(.minute, from: now),
            enabled: true,
            label: "",
            repeatDays: [],
            useMission: false,
            wakeStyle: .defaultSelection
        )
    }
}

// MARK: - Alarm Storage

final class AlarmStore: ObservableObject {
    @Published var alarms: [AlarmItem] = []

    private let key = "zamke_alarms"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data)
        else { return }
        alarms = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ alarm: AlarmItem) {
        alarms.append(alarm)
        save()
        scheduleNotification(for: alarm)
    }

    func update(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
            save()
            cancelNotification(for: alarm)
            if alarm.enabled { scheduleNotification(for: alarm) }
        }
    }

    func delete(_ alarm: AlarmItem) {
        cancelNotification(for: alarm)
        alarms.removeAll { $0.id == alarm.id }
        save()
    }

    func toggle(_ alarm: AlarmItem) {
        var updated = alarm
        updated.enabled.toggle()
        update(updated)
    }

    // MARK: - Notifications

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for alarm: AlarmItem) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "ZAMKE"
        content.body = alarm.label.isEmpty ? "알람" : alarm.label
        content.sound = .default

        if alarm.repeatDays.isEmpty {
            var dc = DateComponents()
            dc.hour = alarm.hour
            dc.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let req = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            center.add(req)
        } else {
            for day in alarm.repeatDays {
                var dc = DateComponents()
                dc.weekday = day
                dc.hour = alarm.hour
                dc.minute = alarm.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let req = UNNotificationRequest(identifier: "\(alarm.id.uuidString)_\(day)", content: content, trigger: trigger)
                center.add(req)
            }
        }
    }

    private func cancelNotification(for alarm: AlarmItem) {
        let center = UNUserNotificationCenter.current()
        var ids = [alarm.id.uuidString]
        for day in 1...7 { ids.append("\(alarm.id.uuidString)_\(day)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Theme Colors

private let bgColor = Color(red: 0.043, green: 0.059, blue: 0.102)
private let cardColor = Color(red: 0.07, green: 0.09, blue: 0.15)
private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.23)
private let textPrimary = Color.white.opacity(0.92)
private let textSecondary = Color.white.opacity(0.55)
private let textTertiary = Color.white.opacity(0.3)

// MARK: - AlarmView

struct AlarmView: View {
    @StateObject private var store = AlarmStore()
    let onBack: () -> Void

    // 피커 상태 (인라인)
    @State private var selAmPm = 0        // 0=AM, 1=PM
    @State private var selHour = 7        // 1~12
    @State private var selMinute = 0      // 0~59
    @State private var repeatDays: Set<Int> = []
    @State private var wakeStyle = WakeStyleSelection.defaultSelection
    @State private var showWakeStylePicker = false

    // 편집 모드
    @State private var editingAlarmId: UUID? = nil

    // 저장 버튼 glow
    @State private var glowPulse = false

    // 삭제 확인
    @State private var alarmToDelete: AlarmItem? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── 시간 피커 ──
                        timePickerSection
                            .padding(.top, 8)

                        Spacer().frame(height: 28)

                        // ── 저장 버튼 ──
                        saveButton

                        Spacer().frame(height: 20)

                        // ── 깨우는 방식 ──
                        wakeStyleButton
                            .padding(.horizontal, 24)

                        Spacer().frame(height: 14)

                        // ── 반복 요일 ──
                        repeatSection
                            .padding(.horizontal, 24)

                        // ── 저장된 알람 목록 ──
                        if !store.alarms.isEmpty {
                            Spacer().frame(height: 28)
                            savedAlarmsList
                                .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            store.requestPermission()
            startGlow()
        }
        .sheet(isPresented: $showWakeStylePicker) {
            WakeStylePickerView(selection: $wakeStyle)
                .presentationDetents([.large])
                .presentationBackground(bgColor)
        }
        .alert("알람을 삭제하시겠습니까?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                if let alarm = alarmToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.delete(alarm)
                    }
                    // 편집 중이던 알람이면 편집 해제
                    if editingAlarmId == alarm.id {
                        editingAlarmId = nil
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { onBack() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("홈")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(textSecondary)
            }

            Spacer()

            Text("알람")
                .font(.system(size: 18, weight: .bold))
                .tracking(1)
                .foregroundColor(textPrimary)

            Spacer()

            // 편집 중이면 "새로" 버튼
            if editingAlarmId != nil {
                Button {
                    resetToNew()
                } label: {
                    Text("새로")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentRed)
                }
            } else {
                Color.clear.frame(width: 44, height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Time Picker (인라인)

    private var timePickerSection: some View {
        HStack(spacing: 0) {
            // AM/PM
            Picker("", selection: $selAmPm) {
                Text("AM").tag(0)
                Text("PM").tag(1)
            }
            .pickerStyle(.wheel)
            .frame(width: 72, height: 190)
            .clipped()

            // Hour (1~12)
            Picker("", selection: $selHour) {
                ForEach(1...12, id: \.self) { h in
                    Text("\(h)").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 72, height: 190)
            .clipped()

            Text(":")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(textSecondary)
                .frame(width: 16)

            // Minute (00~59)
            Picker("", selection: $selMinute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 72, height: 190)
            .clipped()
        }
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardColor)
        )
        .padding(.horizontal, 40)
    }

    // MARK: - Save Button (큰 원형)

    private var saveButton: some View {
        Button { saveAlarm() } label: {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(accentRed.opacity(glowPulse ? 0.12 : 0.06))
                    .frame(width: 130, height: 130)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentRed, accentRed.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(
                        color: accentRed.opacity(0.35),
                        radius: glowPulse ? 20 : 12,
                        y: 4
                    )

                VStack(spacing: 4) {
                    Image(systemName: editingAlarmId != nil ? "checkmark" : "alarm.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)

                    Text(editingAlarmId != nil ? "수정" : "저장")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Wake Style Button

    private var wakeStyleButton: some View {
        Button { showWakeStylePicker = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(wakeStyle.category.iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: wakeStyle.category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(wakeStyle.category.iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("깨우는 사운드")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    Text(wakeStyle.category.title + " — " + wakeStyle.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(cardColor))
        }
    }

    // MARK: - Repeat Days

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("반복")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textSecondary)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ForEach([
                    (1, "일"), (2, "월"), (3, "화"), (4, "수"),
                    (5, "목"), (6, "금"), (7, "토")
                ], id: \.0) { day, name in
                    let selected = repeatDays.contains(day)
                    Button {
                        if selected { repeatDays.remove(day) }
                        else { repeatDays.insert(day) }
                    } label: {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selected ? .white : textSecondary)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(selected ? accentRed.opacity(0.6) : Color.white.opacity(0.06))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(cardColor))
    }

    // MARK: - Saved Alarms List

    private var savedAlarmsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("저장된 알람")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textSecondary)

                Spacer()

                Text("\(store.alarms.count)개")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textTertiary)
            }
            .padding(.horizontal, 4)

            ForEach(store.alarms) { alarm in
                alarmRow(alarm)
            }
        }
    }

    private func alarmRow(_ alarm: AlarmItem) -> some View {
        let isEditing = editingAlarmId == alarm.id

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(alarm.hourMinuteString)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(alarm.enabled ? textPrimary : textTertiary)

                    Text(alarm.ampmString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(alarm.enabled ? textSecondary : textTertiary)
                }

                HStack(spacing: 8) {
                    Text(alarm.repeatString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(alarm.enabled ? textSecondary : textTertiary)

                    HStack(spacing: 4) {
                        Image(systemName: alarm.wakeStyle.category.icon)
                            .font(.system(size: 10))
                        Text(alarm.wakeStyle.displayName)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(alarm.enabled
                        ? alarm.wakeStyle.category.iconColor.opacity(0.7)
                        : textTertiary)
                }
            }
            .onTapGesture {
                loadAlarmForEditing(alarm)
            }

            Spacer()

            // 삭제 버튼
            Button {
                alarmToDelete = alarm
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(textTertiary)
                    .frame(width: 36, height: 36)
            }
            .padding(.trailing, 6)

            ZamkeToggle(isOn: alarm.enabled) {
                store.toggle(alarm)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor.opacity(alarm.enabled ? 1 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditing ? accentRed.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Glow Animation

    private func startGlow() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    // MARK: - Actions

    private var hour24: Int {
        var h = selHour % 12   // 12 → 0
        if selAmPm == 1 { h += 12 }
        return h
    }

    private func saveAlarm() {
        if let editId = editingAlarmId {
            // 기존 알람 수정
            let alarm = AlarmItem(
                id: editId,
                hour: hour24,
                minute: selMinute,
                enabled: true,
                label: "",
                repeatDays: repeatDays,
                useMission: wakeStyle.category == .hwadeuljjak,
                wakeStyle: wakeStyle
            )
            store.update(alarm)
            editingAlarmId = nil
        } else {
            // 새 알람 추가
            let alarm = AlarmItem(
                id: UUID(),
                hour: hour24,
                minute: selMinute,
                enabled: true,
                label: "",
                repeatDays: repeatDays,
                useMission: wakeStyle.category == .hwadeuljjak,
                wakeStyle: wakeStyle
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                store.add(alarm)
            }
        }
    }

    private func loadAlarmForEditing(_ alarm: AlarmItem) {
        editingAlarmId = alarm.id
        selAmPm = alarm.hour < 12 ? 0 : 1
        let h12 = alarm.hour % 12
        selHour = h12 == 0 ? 12 : h12
        selMinute = alarm.minute
        repeatDays = alarm.repeatDays
        wakeStyle = alarm.wakeStyle
    }

    private func resetToNew() {
        editingAlarmId = nil
        let cal = Calendar.current
        let now = Date()
        let currentHour = cal.component(.hour, from: now)
        selAmPm = currentHour < 12 ? 0 : 1
        let h12 = currentHour % 12
        selHour = h12 == 0 ? 12 : h12
        selMinute = cal.component(.minute, from: now)
        repeatDays = []
        wakeStyle = .defaultSelection
    }
}

// MARK: - Scale Button Style (glow + press)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Custom Toggle

struct ZamkeToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? accentRed.opacity(0.6) : Color.white.opacity(0.1))
                .frame(width: 52, height: 32)
                .overlay(
                    Circle()
                        .fill(isOn ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .offset(x: isOn ? 10 : -10),
                    alignment: .center
                )
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
    }
}

// MARK: - Editor Result (하위 호환)

enum AlarmEditorResult {
    case save(AlarmItem)
    case delete(AlarmItem)
    case cancel
}
