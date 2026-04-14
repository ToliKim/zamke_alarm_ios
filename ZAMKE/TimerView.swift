//
//  TimerView.swift
//  ZAMKE
//
//  타이머 모드 — 기능 영역
//  1초 ~ 23시간 59분 59초 (초 단위)
//  딥 네이비 배경 + 큰 시작 버튼 + 자주쓰기
//

import SwiftUI
import Combine
import UserNotifications
import AVFoundation

// MARK: - Theme (AlarmView와 공유)

private let bgColor = Color(red: 0.043, green: 0.059, blue: 0.102)
private let cardColor = Color(red: 0.07, green: 0.09, blue: 0.15)
private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.23)
private let textPrimary = Color.white.opacity(0.92)
private let textSecondary = Color.white.opacity(0.55)
private let textTertiary = Color.white.opacity(0.3)

// MARK: - Preset Model

struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var hours: Int
    var minutes: Int
    var seconds: Int
    var label: String

    var totalSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    var displayTime: String {
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)시간") }
        if minutes > 0 { parts.append("\(minutes)분") }
        if seconds > 0 { parts.append("\(seconds)초") }
        return parts.isEmpty ? "0초" : parts.joined(separator: " ")
    }
}

// MARK: - Preset Storage

final class PresetStore: ObservableObject {
    @Published var presets: [TimerPreset] = []

    private let key = "zamke_timer_presets_v2"

    init() {
        load()
        while presets.count < 3 {
            presets.append(TimerPreset(id: UUID(), hours: 0, minutes: 0, seconds: 0, label: ""))
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TimerPreset].self, from: data)
        else { return }
        presets = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func update(index: Int, hours: Int, minutes: Int, seconds: Int, label: String) {
        guard index < presets.count else { return }
        presets[index] = TimerPreset(id: presets[index].id, hours: hours, minutes: minutes, seconds: seconds, label: label)
        save()
    }
}

// MARK: - TimerView

struct TimerView: View {
    @StateObject private var presetStore = PresetStore()
    let onBack: () -> Void

    // 피커 상태: 0~23시간, 0~59분, 0~59초
    @State private var selectedHour = 0
    @State private var selectedMinute = 5
    @State private var selectedSecond = 0

    // 카운트다운 상태
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var remainingSeconds = 0
    @State private var totalSetSeconds = 0
    @State private var countdownTimer: Timer? = nil

    // 깨우는 방식
    @State private var wakeStyle = WakeStyleSelection.defaultSelection
    @State private var showWakeStylePicker = false

    // 타이머 완료 사운드
    @State private var alarmPlayer: AVAudioPlayer?
    @State private var timerDone = false
    @State private var showHwadeuljjak = false

    // 시작 버튼 glow
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if timerDone {
                    timerDoneView
                } else if isRunning {
                    countdownView
                } else {
                    pickerView
                }
            }
        }
        .onAppear { startGlow() }
        .sheet(isPresented: $showWakeStylePicker) {
            WakeStylePickerView(selection: $wakeStyle)
                .presentationDetents([.large])
                .presentationBackground(bgColor)
        }
        .fullScreenCover(isPresented: $showHwadeuljjak) {
            HwadeuljjakView(onBack: {
                showHwadeuljjak = false
            })
        }
        .onDisappear {
            countdownTimer?.invalidate()
            alarmPlayer?.stop()
            alarmPlayer = nil
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
            .opacity(isRunning || timerDone ? 0.3 : 1)
            .disabled(isRunning || timerDone)

            Spacer()

            Text("타이머")
                .font(.system(size: 18, weight: .bold))
                .tracking(1)
                .foregroundColor(textPrimary)

            Spacer()

            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Picker View

    private var pickerView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 16)

            // ── 3열 스크롤 피커: 시 · 분 · 초 ──
            HStack(spacing: 0) {
                // 시간 (0~23)
                Picker("", selection: $selectedHour) {
                    ForEach(0...23, id: \.self) { h in
                        Text("\(h)")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white)
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 180)
                .clipped()

                Text("시")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                    .frame(width: 24)

                // 분 (0~59)
                Picker("", selection: $selectedMinute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white)
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 180)
                .clipped()

                Text("분")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                    .frame(width: 24)

                // 초 (0~59)
                Picker("", selection: $selectedSecond) {
                    ForEach(0..<60, id: \.self) { s in
                        Text(String(format: "%02d", s))
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white)
                            .tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 64, height: 180)
                .clipped()

                Text("초")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                    .frame(width: 24)
            }
            .environment(\.colorScheme, .dark)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardColor)
            )
            .padding(.horizontal, 28)
            .onChange(of: selectedHour) { clampTime() }
            .onChange(of: selectedMinute) { clampTime() }
            .onChange(of: selectedSecond) { clampTime() }

            Spacer()
                .frame(height: 32)

            // ── 시작 버튼 ──
            Button { startTimer() } label: {
                ZStack {
                    Circle()
                        .fill(accentRed.opacity(glowPulse ? 0.12 : 0.06))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(
                            isValidTime
                            ? LinearGradient(
                                colors: [accentRed, accentRed.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(
                            color: isValidTime ? accentRed.opacity(0.35) : .clear,
                            radius: glowPulse ? 20 : 12,
                            y: 4
                        )

                    Text("시작")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(2)
                        .foregroundColor(isValidTime ? .white : textTertiary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!isValidTime)

            Spacer()
                .frame(height: 20)

            // ── 깨우는 방식 ──
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
                        Text(wakeStyle.displayName)
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
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 16)

            // ── 자주쓰기 3슬롯 ──
            VStack(alignment: .leading, spacing: 10) {
                Text("자주 쓰기")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 4)

                ForEach(0..<3, id: \.self) { idx in
                    presetRow(index: idx)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 30)
        }
    }

    // MARK: - Preset Row

    private func presetRow(index: Int) -> some View {
        let preset = presetStore.presets[index]
        let isEmpty = preset.totalSeconds == 0

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isEmpty ? Color.white.opacity(0.04) : accentRed.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isEmpty ? textTertiary : accentRed.opacity(0.8))
            }

            if isEmpty {
                Button {
                    saveCurrentToPreset(index: index)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("현재 시간 저장")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(textTertiary)
                }
                Spacer()
            } else {
                Button {
                    selectedHour = preset.hours
                    selectedMinute = preset.minutes
                    selectedSecond = preset.seconds
                } label: {
                    Text(preset.displayTime)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                }

                Spacer()

                Button {
                    presetStore.update(index: index, hours: 0, minutes: 0, seconds: 0, label: "")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardColor)
        )
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 270, height: 270)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        accentRed.opacity(0.7),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 270, height: 270)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                    .shadow(color: accentRed.opacity(0.3), radius: 8)

                VStack(spacing: 10) {
                    Text(timeString)
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()

                    if isPaused {
                        Text("일시정지")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentRed.opacity(0.7))
                    }
                }
            }

            Spacer()

            HStack(spacing: 50) {
                Button { cancelTimer() } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 64, height: 64)
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(textSecondary)
                        }
                        Text("취소")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textTertiary)
                    }
                }

                Button { togglePause() } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(accentRed.opacity(0.5))
                                .frame(width: 64, height: 64)
                                .shadow(color: accentRed.opacity(0.25), radius: 10, y: 2)
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(isPaused ? "재개" : "정지")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textTertiary)
                    }
                }
            }

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Timer Done View (알람 울리는 중)

    private var timerDoneView: some View {
        VStack(spacing: 0) {
            Spacer()

            // 사운드 아이콘 + 펄스
            ZStack {
                Circle()
                    .fill(accentRed.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .scaleEffect(glowPulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: glowPulse)

                Circle()
                    .fill(accentRed.opacity(0.25))
                    .frame(width: 140, height: 140)

                Image(systemName: wakeStyle.category.icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer().frame(height: 32)

            Text("타이머 종료")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textPrimary)

            Spacer().frame(height: 8)

            Text(wakeStyle.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textSecondary)

            Spacer()

            // 중지 버튼
            Button { stopAlarm() } label: {
                ZStack {
                    Circle()
                        .fill(accentRed)
                        .frame(width: 90, height: 90)
                        .shadow(color: accentRed.opacity(0.4), radius: 16, y: 4)

                    Text("끄기")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Spacer().frame(height: 80)
        }
    }

    // MARK: - Glow Animation

    private func startGlow() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    // MARK: - Timer Logic

    private var isValidTime: Bool {
        selectedHour > 0 || selectedMinute > 0 || selectedSecond > 0
    }

    private var progress: CGFloat {
        guard totalSetSeconds > 0 else { return 0 }
        return CGFloat(remainingSeconds) / CGFloat(totalSetSeconds)
    }

    private var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func clampTime() {
        // 최소 1초, 최대 23:59:59
        let total = selectedHour * 3600 + selectedMinute * 60 + selectedSecond
        if total == 0 {
            selectedSecond = 1
        }
        if selectedHour >= 23 && selectedMinute >= 59 && selectedSecond > 59 {
            selectedSecond = 59
        }
        if selectedHour > 23 {
            selectedHour = 23
            selectedMinute = 59
            selectedSecond = 59
        }
    }

    private func startTimer() {
        guard isValidTime else { return }
        totalSetSeconds = selectedHour * 3600 + selectedMinute * 60 + selectedSecond
        remainingSeconds = totalSetSeconds
        isRunning = true
        isPaused = false
        scheduleCountdown()
        scheduleNotification()
    }

    private func scheduleCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 { remainingSeconds -= 1 }
            else { timerFinished() }
        }
    }

    private func togglePause() {
        if isPaused {
            isPaused = false
            scheduleCountdown()
            scheduleNotification()
        } else {
            isPaused = true
            countdownTimer?.invalidate()
            cancelNotification()
        }
    }

    private func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        cancelNotification()
        isRunning = false
        isPaused = false
    }

    private func timerFinished() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        // 햅틱
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        isRunning = false
        isPaused = false

        if wakeStyle.category == .hwadeuljjak {
            // 화들짝 → 풀 미션 모드 실행
            showHwadeuljjak = true
        } else {
            // 일반 사운드 재생
            playWakeSound()
            timerDone = true
        }
    }

    private func playWakeSound() {
        guard let sound = wakeStyle.sound,
              let (folder, name) = sound.previewFile else {
            // previewFile이 없는 경우 (화들짝 등) → 기본 벨1 재생
            playAudioFile(folder: "Bell", name: "b1")
            return
        }
        playAudioFile(folder: folder, name: name)
    }

    private func playAudioFile(folder: String, name: String) {
        let url: URL? = {
            if let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/\(folder)") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: folder) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: "wav") { return u }
            if let bp = Bundle.main.resourcePath,
               let en = FileManager.default.enumerator(atPath: bp) {
                while let p = en.nextObject() as? String {
                    if p.hasSuffix("/\(name).wav") || p == "\(name).wav" {
                        return URL(fileURLWithPath: bp).appendingPathComponent(p)
                    }
                }
            }
            return nil
        }()

        guard let fileURL = url else {
            #if DEBUG
            print("⚠️ 타이머 사운드 없음: \(folder)/\(name).wav")
            #endif
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            alarmPlayer = try AVAudioPlayer(contentsOf: fileURL)
            alarmPlayer?.numberOfLoops = -1  // 무한 반복
            alarmPlayer?.volume = 1.0
            alarmPlayer?.play()
        } catch {
            #if DEBUG
            print("❌ 타이머 사운드 재생 실패: \(error)")
            #endif
        }
    }

    private func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        timerDone = false
        isRunning = false
    }

    private func saveCurrentToPreset(index: Int) {
        guard isValidTime else { return }
        presetStore.update(index: index, hours: selectedHour, minutes: selectedMinute, seconds: selectedSecond, label: "")
    }

    // MARK: - Notification

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "ZAMKE"
        content.body = "타이머 종료"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds), repeats: false
        )
        let req = UNNotificationRequest(identifier: "zamke_timer", content: content, trigger: trigger)
        center.add(req)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["zamke_timer"])
    }
}
