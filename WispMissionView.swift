//
//  WispMissionView.swift
//  ZAMKE
//
//  미션 5: 도깨비불 포획
//
//  화면에 떠다니는 도깨비불(빛)을 폰 기울기로 포획 원을 움직여 잡는다.
//  도깨비불은 포획 원이 접근하면 반대 방향으로 도망.
//  5개 포획 → 성공. 45초 제한.
//
//  입력: 자이로스코프 (CMMotionManager.deviceMotion — attitude.roll, pitch)
//  화면: 02.png 배경 + 도깨비불 + 포획 원 + 타이머
//

import SwiftUI
import CoreMotion

struct WispMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 게임 상태 ──
    enum Phase { case playing, failed, cleared }

    @State private var phase: Phase = .playing
    @State private var alive = true
    @State private var captured = 0
    private let totalCaptures = 5
    private let timeLimit: Double = 45.0

    // ── 센서 ──
    @State private var motionManager = CMMotionManager()
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0

    // ── 포획 원 (사용자 제어) ──
    @State private var captureX: CGFloat = 0
    @State private var captureY: CGFloat = 0
    private let captureRadius: CGFloat = 40

    // ── 도깨비불 ──
    @State private var wispX: CGFloat = 0
    @State private var wispY: CGFloat = 0
    @State private var wispTargetX: CGFloat = 0
    @State private var wispTargetY: CGFloat = 0
    private let wispRadius: CGFloat = 25
    @State private var wispPulse: CGFloat = 1.0
    @State private var wispColor: Color = Color(red: 1.0, green: 0.53, blue: 0.0)

    // ── 포획 타이머 (2초 겹치면 포획) ──
    @State private var overlapTime: Double = 0
    private let captureTime: Double = 1.5  // 1.5초 겹침 필요

    // ── 게임 타이머 ──
    @State private var gameTimer: Timer?
    @State private var timeRemaining: Double = 45.0
    @State private var gameStartTime: Date = Date()

    // ── 02.png ──
    @State private var reaperBlur: CGFloat = 6
    @State private var reaperOpacity: Double = 0.15

    // ── 포획 진행 링 ──
    @State private var captureProgress: Double = 0

    // ── 화면 크기 ──
    @State private var screenWidth: CGFloat = 0
    @State private var screenHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 02.png 배경 ──
                Image("02")
                    .resizable()
                    .scaledToFit()
                    .blur(radius: reaperBlur)
                    .opacity(reaperOpacity)
                    .allowsHitTesting(false)

                // ── 도깨비불 ──
                ZStack {
                    // 외부 glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    wispColor.opacity(0.6),
                                    wispColor.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(wispPulse)

                    // 코어
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.95, blue: 0.7),
                                    wispColor
                                ],
                                center: .center,
                                startRadius: 3,
                                endRadius: wispRadius
                            )
                        )
                        .frame(width: wispRadius * 2, height: wispRadius * 2)
                        .shadow(color: wispColor.opacity(0.5), radius: 15)
                }
                .position(x: wispX, y: wispY)

                // ── 포획 원 ──
                ZStack {
                    // 진행 링
                    Circle()
                        .trim(from: 0, to: captureProgress)
                        .stroke(Color.green.opacity(0.7), lineWidth: 3)
                        .frame(width: captureRadius * 2 + 10, height: captureRadius * 2 + 10)
                        .rotationEffect(.degrees(-90))

                    // 포획 원
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: captureRadius * 2, height: captureRadius * 2)

                    // 십자선
                    Path { p in
                        p.move(to: CGPoint(x: -8, y: 0))
                        p.addLine(to: CGPoint(x: 8, y: 0))
                        p.move(to: CGPoint(x: 0, y: -8))
                        p.addLine(to: CGPoint(x: 0, y: 8))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                }
                .position(x: captureX, y: captureY)
                .shadow(color: .white.opacity(0.2), radius: 6)

                // ── UI 오버레이 ──
                VStack {
                    HStack {
                        // 포획 수
                        HStack(spacing: 5) {
                            ForEach(0..<totalCaptures, id: \.self) { i in
                                Circle()
                                    .fill(i < captured
                                          ? Color(red: 1.0, green: 0.53, blue: 0.0)
                                          : Color.white.opacity(0.12))
                                    .frame(width: 10, height: 10)
                            }
                        }

                        Spacer()

                        // 남은 시간
                        Text("\(String(format: "%.0f", timeRemaining))초")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(timeRemaining < 10
                                ? Color(red: 1.0, green: 0.23, blue: 0.23)
                                : .white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer()

                    // 상태
                    if phase == .playing {
                        Text("기울여라")
                            .font(Font.system(size: 28, weight: .black).width(.condensed))
                            .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96))
                            .shadow(color: .white.opacity(0.2), radius: 8)
                    }

                    Spacer().frame(height: 50)
                }

                // ── 실패 ──
                if phase == .failed {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    Text("시간 초과")
                        .font(Font.system(size: 48, weight: .black).width(.condensed))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.6), radius: 30)
                }
            }
            .onAppear {
                screenWidth = geo.size.width
                screenHeight = geo.size.height
                startGame()
            }
            .onDisappear { cleanup() }
        }
    }

    // MARK: - 게임 시작

    private func startGame() {
        alive = true
        captured = 0
        timeRemaining = timeLimit
        gameStartTime = Date()

        // 초기 위치
        captureX = screenWidth / 2
        captureY = screenHeight / 2
        spawnWisp()

        startMotion()
        startGameLoop()
        startWispPulse()
    }

    // MARK: - 센서

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [self] motion, _ in
            guard let m = motion, alive else { return }
            tiltX = m.attitude.roll * 180 / .pi
            tiltY = m.attitude.pitch * 180 / .pi
        }
    }

    // MARK: - 도깨비불 스폰

    private func spawnWisp() {
        let margin: CGFloat = 80
        wispX = CGFloat.random(in: margin...(screenWidth - margin))
        wispY = CGFloat.random(in: margin...(screenHeight - margin))
        wispTargetX = wispX
        wispTargetY = wispY
        overlapTime = 0
        captureProgress = 0
        wispColor = Color(red: 1.0, green: 0.53, blue: 0.0)
    }

    // MARK: - 게임 루프

    private func startGameLoop() {
        gameTimer?.invalidate()
        let gt = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive, phase == .playing else { return }

            let dt: Double = 0.033

            // 시간 업데이트
            timeRemaining = max(0, timeLimit - Date().timeIntervalSince(gameStartTime))
            if timeRemaining <= 0 {
                gameTimer?.invalidate()
                missionFailed()
                return
            }

            // 포획 원 이동 (기울기 기반)
            let maxTilt: Double = 25
            let speed: CGFloat = 8
            captureX += CGFloat(tiltX / maxTilt) * speed
            captureY += CGFloat(tiltY / maxTilt) * speed

            // 화면 내 제한
            captureX = max(captureRadius, min(screenWidth - captureRadius, captureX))
            captureY = max(captureRadius, min(screenHeight - captureRadius, captureY))

            // 도깨비불 ↔ 포획 원 거리
            let dx = Double(wispX - captureX)
            let dy = Double(wispY - captureY)
            let dist = sqrt(dx * dx + dy * dy)

            // 도깨비불 도망 메카닉
            let fleeRadius: Double = 100 + Double(captured) * 15  // 후반부 도망 반경 증가
            if dist < fleeRadius && dist > 1 {
                // 반대 방향으로 도망
                let fleeSpeed: CGFloat = CGFloat(3.0 + Double(captured) * 0.8)  // 후반부 속도 증가
                let nx = CGFloat(dx / dist) // 포획원→도깨비불 방향
                let ny = CGFloat(dy / dist)
                wispTargetX = wispX + nx * fleeSpeed * 3
                wispTargetY = wispY + ny * fleeSpeed * 3

                // 화면 내 제한
                let m: CGFloat = 50
                wispTargetX = max(m, min(screenWidth - m, wispTargetX))
                wispTargetY = max(m, min(screenHeight - m, wispTargetY))
            }

            // 도깨비불 이동 (부드럽게)
            let moveSpeed: CGFloat = 0.08
            wispX += (wispTargetX - wispX) * moveSpeed
            wispY += (wispTargetY - wispY) * moveSpeed

            // 랜덤 drift (자연스러운 움직임)
            wispTargetX += CGFloat.random(in: -1.5...1.5)
            wispTargetY += CGFloat.random(in: -1.5...1.5)
            let m: CGFloat = 50
            wispTargetX = max(m, min(screenWidth - m, wispTargetX))
            wispTargetY = max(m, min(screenHeight - m, wispTargetY))

            // 포획 판정 (겹침)
            let overlapDist = Double(captureRadius + wispRadius)
            if dist < overlapDist {
                overlapTime += dt
                captureProgress = min(1.0, overlapTime / captureTime)

                // 색상 변화: 가까우면 붉어짐
                wispColor = Color(
                    red: 1.0,
                    green: max(0.23, 0.53 - captureProgress * 0.3),
                    blue: max(0.0, 0.0)
                )

                if overlapTime >= captureTime {
                    // 포획!
                    captureWisp()
                }
            } else {
                overlapTime = max(0, overlapTime - dt * 2)  // 느리게 감소
                captureProgress = max(0, overlapTime / captureTime)
                wispColor = Color(red: 1.0, green: 0.53, blue: 0.0)
            }

            // 02.png blur: 포획 수에 따라 감소
            let newBlur = 6.0 - Double(captured) * 1.0
            reaperBlur = CGFloat(max(0.5, newBlur))
            reaperOpacity = 0.15 + Double(captured) * 0.12
        }
        RunLoop.main.add(gt, forMode: .common)
        gameTimer = gt
    }

    // MARK: - 포획

    private func captureWisp() {
        captured += 1
        overlapTime = 0
        captureProgress = 0

        // 햅틱
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        if captured >= totalCaptures {
            gameTimer?.invalidate()
            missionCleared()
        } else {
            // 새 도깨비불 스폰
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                spawnWisp()
            }
        }
    }

    // MARK: - 맥동

    private func startWispPulse() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            wispPulse = 1.15
        }
    }

    // MARK: - 실패

    private func missionFailed() {
        guard alive else { return }
        alive = false
        phase = .failed

        audioEngine?.fireAjaeng()

        withAnimation(.easeIn(duration: 0.1)) {
            reaperBlur = 0
            reaperOpacity = 0.7
        }

        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { gen.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { gen.impactOccurred() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            onResult(.failure)
        }
    }

    // MARK: - 클리어

    private func missionCleared() {
        guard alive else { return }
        alive = false
        phase = .cleared

        withAnimation(.easeOut(duration: 1.0)) {
            reaperBlur = 15
            reaperOpacity = 0
            wispPulse = 0.3
        }

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            onResult(.success)
        }
    }

    // MARK: - 정리

    private func cleanup() {
        alive = false
        gameTimer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }
}
