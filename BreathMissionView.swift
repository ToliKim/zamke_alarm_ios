//
//  BreathMissionView.swift
//  ZAMKE
//
//  미션 4: 숨소리 탐지
//
//  저승사자가 숨소리를 듣고 있다.
//  "숨 참기" (조용히) ↔ "불어라" (마이크에 바람) 교차 반복 × 5회
//
//  입력: 마이크 (AVAudioRecorder — averagePower metering)
//  화면: 02.png 중앙 + 소리 레벨 바 + 지시 텍스트 + 카운트다운
//

import SwiftUI
import AVFoundation

struct BreathMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 게임 상태 ──
    enum Phase { case ready, holdBreath, blow, failed, cleared }

    @State private var phase: Phase = .ready
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 5
    @State private var failCount = 0

    // ── 마이크 ──
    @State private var recorder: AVAudioRecorder?
    @State private var meterTimer: Timer?
    @State private var dbLevel: Float = -80       // 현재 dB
    @State private var normalizedLevel: Double = 0 // 0~1 표시용

    // ── Hold Breath ──
    @State private var holdDuration: Double = 3.0   // 숨 참기 시간 (초)
    @State private var holdProgress: Double = 0     // 0~1
    @State private var holdDetections = 0           // 소리 감지 횟수
    private let holdThreshold: Float = -40          // dB — 이 이상이면 "소리 냄"
    private let maxHoldDetections = 2

    // ── Blow ──
    @State private var blowGauge: Double = 0        // 0~1
    @State private var blowTimeLeft: Double = 5.0   // 남은 시간
    private let blowThreshold: Float = -20          // dB — 이 이상이면 "불기" 감지
    private let blowRequiredDuration: Double = 1.5  // 게이지 100% 필요 시간

    // ── 타이머 ──
    @State private var gameTimer: Timer?

    // ── 02.png ──
    @State private var reaperBlur: CGFloat = 8
    @State private var reaperOpacity: Double = 0.4
    @State private var reaperScale: CGFloat = 1.0
    @State private var eyeGlow: Double = 0

    // ── 시각 ──
    @State private var statusText = "준비"
    @State private var statusColor = Color(red: 0.96, green: 0.96, blue: 0.96)
    @State private var screenDim: Double = 0        // 숨 참기 중 화면 어두워짐
    @State private var caughtFlash = false

    var body: some View {
        ZStack {
            // ── 02.png ──
            Image("02")
                .resizable()
                .scaledToFit()
                .blur(radius: reaperBlur)
                .opacity(reaperOpacity)
                .scaleEffect(reaperScale)
                .contrast(1.2 + eyeGlow * 0.3)
                .allowsHitTesting(false)

            // ── 눈 glow ──
            if eyeGlow > 0.1 {
                RadialGradient(
                    colors: [
                        Color.red.opacity(eyeGlow * 0.5),
                        Color.red.opacity(eyeGlow * 0.12),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.33),
                    startRadius: 5,
                    endRadius: 60
                )
                .allowsHitTesting(false)
            }

            // ── 숨 참기 중 어두워짐 ──
            Color.black.opacity(screenDim)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // ── 실패 플래시 ──
            if caughtFlash {
                Color.red.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // ── UI ──
            VStack {
                // 회차 인디케이터
                HStack(spacing: 8) {
                    ForEach(0..<totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i < round
                                  ? Color.green.opacity(0.7)
                                  : (i == round
                                     ? Color(red: 1.0, green: 0.23, blue: 0.23)
                                     : Color.white.opacity(0.12)))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 20)

                Spacer()

                // 소리 레벨 바
                soundLevelBar
                    .padding(.horizontal, 40)

                Spacer().frame(height: 30)

                // 상태 텍스트
                Text(statusText)
                    .font(Font.system(size: 34, weight: .black).width(.condensed))
                    .tracking(2)
                    .foregroundColor(statusColor)
                    .shadow(color: statusColor.opacity(0.4), radius: 12)

                // 페이즈별 게이지
                if phase == .holdBreath {
                    // 카운트다운 바
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.green.opacity(0.6))
                                .frame(width: geo.size.width * holdProgress, height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 50)
                    .padding(.top, 12)

                    Text("\(String(format: "%.0f", holdDuration * (1 - holdProgress)))초")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)
                }

                if phase == .blow {
                    // 불기 게이지
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(blowGauge > 0.8
                                      ? Color.green.opacity(0.7)
                                      : Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.7))
                                .frame(width: geo.size.width * blowGauge, height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 50)
                    .padding(.top, 12)

                    Text("\(String(format: "%.0f", blowTimeLeft))초")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(blowTimeLeft < 2
                            ? Color(red: 1.0, green: 0.23, blue: 0.23)
                            : .white.opacity(0.4))
                        .padding(.top, 4)
                }

                Spacer().frame(height: 60)
            }

            // ── "들켰다" ──
            if phase == .failed {
                Text("들켰다")
                    .font(Font.system(size: 56, weight: .black).width(.condensed))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.6), radius: 30)
            }
        }
        .onAppear { startGame() }
        .onDisappear { cleanup() }
    }

    // MARK: - 소리 레벨 바

    private var soundLevelBar: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    let threshold = Double(i) / 20.0
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(index: i, level: normalizedLevel))
                        .frame(width: (geo.size.width - 57) / 20, height: 16)
                        .opacity(normalizedLevel >= threshold ? 1.0 : 0.15)
                }
            }
        }
        .frame(height: 16)
    }

    private func barColor(index: Int, level: Double) -> Color {
        if index < 10 {
            return Color.green.opacity(0.7)
        } else if index < 15 {
            return Color.yellow.opacity(0.7)
        } else {
            return Color.red.opacity(0.8)
        }
    }

    // MARK: - 게임 시작

    private func startGame() {
        alive = true
        round = 0
        failCount = 0
        phase = .ready
        setupMicrophone()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            enterHoldBreath()
        }
    }

    // MARK: - 마이크 설정

    private func setupMicrophone() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("❌ 마이크 설정 실패: \(error)")
            #endif
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zamke_breath.caf")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            #if DEBUG
            print("❌ 레코더 생성 실패: \(error)")
            #endif
        }

        // 미터링 타이머 (.common 모드)
        let mt = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            guard let rec = recorder, rec.isRecording else { return }
            rec.updateMeters()
            dbLevel = rec.averagePower(forChannel: 0)
            // -80dB ~ 0dB → 0~1
            normalizedLevel = max(0, min(1, Double(dbLevel + 80) / 80.0))
        }
        RunLoop.main.add(mt, forMode: .common)
        meterTimer = mt
    }

    // MARK: - Phase: 숨 참기

    private func enterHoldBreath() {
        guard alive else { return }
        phase = .holdBreath
        holdProgress = 0
        holdDetections = 0
        screenDim = 0

        // 후반부 숨 참기 시간 증가
        holdDuration = 3.0 + Double(round) * 0.4

        statusText = "숨을 참아라"
        statusColor = Color(red: 0.96, green: 0.96, blue: 0.96)

        // 02.png: 귀 기울이는 상태
        withAnimation(.easeIn(duration: 0.3)) {
            reaperBlur = 6
            reaperOpacity = 0.45
            reaperScale = 1.0
            eyeGlow = 0.2
        }

        // 드론 억제 → 침묵
        audioEngine?.beginSuppression()

        gameTimer?.invalidate()
        let startTime = Date()
        let gt1 = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            guard alive, phase == .holdBreath else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            holdProgress = min(1.0, elapsed / holdDuration)

            // 화면 서서히 어두워짐
            screenDim = min(0.3, elapsed / holdDuration * 0.3)

            // 소리 감지 체크
            if dbLevel > holdThreshold {
                holdDetections += 1

                // 02.png 눈 glow 강화
                withAnimation(.easeIn(duration: 0.1)) {
                    eyeGlow = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                    withAnimation(.easeOut(duration: 0.2)) {
                        eyeGlow = 0.2
                    }
                }

                // 햅틱 경고
                let gen = UIImpactFeedbackGenerator(style: .rigid)
                gen.impactOccurred()

                if holdDetections > maxHoldDetections {
                    // 실패
                    gameTimer?.invalidate()
                    breathFailed()
                    return
                }
            }

            // 시간 경과 → 성공 → 불기로
            if holdProgress >= 1.0 {
                gameTimer?.invalidate()
                enterBlow()
            }
        }
        RunLoop.main.add(gt1, forMode: .common)
        gameTimer = gt1
    }

    // MARK: - Phase: 불기

    private func enterBlow() {
        guard alive else { return }
        phase = .blow
        blowGauge = 0
        blowTimeLeft = 5.0
        screenDim = 0

        statusText = "불어라"
        statusColor = Color(red: 1.0, green: 0.23, blue: 0.23)

        // 02.png: 약간 밀려나는 상태
        withAnimation(.easeOut(duration: 0.2)) {
            reaperBlur = 4
            reaperOpacity = 0.55
            eyeGlow = 0
        }

        audioEngine?.endSuppression()

        // 햅틱 전환 알림
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred()

        gameTimer?.invalidate()
        let startTime = Date()
        let gt2 = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            guard alive, phase == .blow else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            blowTimeLeft = max(0, 5.0 - elapsed)

            // 불기 감지
            if dbLevel > blowThreshold {
                blowGauge = min(1.0, blowGauge + 0.05 / blowRequiredDuration)
            } else {
                // 감쇠 (안 불면 게이지 내려감)
                blowGauge = max(0, blowGauge - 0.008)
            }

            // 02.png 뒤로 밀림 효과
            let pushBack = blowGauge * 0.15
            withAnimation(.easeOut(duration: 0.1)) {
                reaperScale = CGFloat(1.0 - pushBack)
                reaperBlur = CGFloat(4 + blowGauge * 6)
            }

            // 게이지 100% → 라운드 성공
            if blowGauge >= 1.0 {
                gameTimer?.invalidate()
                roundCleared()
                return
            }

            // 시간 초과 → 실패
            if blowTimeLeft <= 0 {
                gameTimer?.invalidate()
                breathFailed()
                return
            }
        }
        RunLoop.main.add(gt2, forMode: .common)
        gameTimer = gt2
    }

    // MARK: - 라운드 클리어

    private func roundCleared() {
        guard alive else { return }
        round += 1

        // 02.png 떨림 + 후퇴
        withAnimation(.easeOut(duration: 0.15)) {
            reaperScale = 0.88
            reaperBlur = 10
        }

        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.impactOccurred()

        if round >= totalRounds {
            // 전체 클리어
            missionCleared()
        } else {
            // 다음 라운드
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                enterHoldBreath()
            }
        }
    }

    // MARK: - 실패

    private func breathFailed() {
        guard alive else { return }
        alive = false
        phase = .failed

        caughtFlash = true
        audioEngine?.endSuppression()
        audioEngine?.fireAjaeng()

        withAnimation(.easeIn(duration: 0.1)) {
            reaperBlur = 0
            reaperOpacity = 0.85
            reaperScale = 1.2
            eyeGlow = 1.0
        }

        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { gen.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { gen.impactOccurred() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            onResult(.failure)
        }
    }

    // MARK: - 전체 클리어

    private func missionCleared() {
        guard alive else { return }
        alive = false
        phase = .cleared

        statusText = "살았다"
        statusColor = .green

        withAnimation(.easeOut(duration: 0.8)) {
            reaperBlur = 15
            reaperOpacity = 0
            reaperScale = 0.7
            eyeGlow = 0
        }

        audioEngine?.endSuppression()

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            onResult(.success)
        }
    }

    // MARK: - 정리

    private func cleanup() {
        alive = false
        gameTimer?.invalidate()
        meterTimer?.invalidate()
        recorder?.stop()
        recorder = nil
    }
}
