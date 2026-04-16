//
//  ReaperGazeMissionView.swift
//  ZAMKE
//
//  미션 1: 저승의 시선
//
//  02.png 저승사자의 두 눈이 번갈아 빛난다.
//  빛나는 눈을 3초 동안 꾹 누르면 → 눈동자(구체)가 튀어나온다.
//  화살표 방향으로 구체를 밀어 화면 밖으로 내보내면 성공.
//
//  5라운드. 라운드마다 눈 전환 빨라짐, 시간 제한 줄어듦.
//
//  ⚠️ 안정성:
//  - .task {} 사용
//  - gameStarted 플래그
//  - onDisappear cleanup
//  - CoreMotion 사용 안 함
//

import SwiftUI

struct ReaperGazeMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 페이즈 ──
    enum Phase { case darkness, eyeGlowing, holding, orbAlive, evaded, failed }
    enum WhichEye { case left, right }
    enum PushDir: CaseIterable { case up, down, left, right }

    @State private var phase: Phase = .darkness
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 5

    // ── 눈 ──
    @State private var activeEye: WhichEye = .left
    @State private var holdProgress: Double = 0        // 0~1 (3초 = 1.0)
    private let holdDuration: Double = 3.0
    @State private var leftEyeGlow: Double = 0
    @State private var rightEyeGlow: Double = 0
    @State private var eyePulse: CGFloat = 1.0

    // ── 구체 ──
    @State private var orbX: CGFloat = 0
    @State private var orbY: CGFloat = 0
    @State private var orbVX: CGFloat = 0
    @State private var orbVY: CGFloat = 0
    @State private var orbVisible = false
    @State private var orbGrabbed = false
    @State private var userFlung = false
    @State private var orbPulse: CGFloat = 1.0
    @State private var pushTimeLeft: Double = 0
    private let pushTimeLimit: Double = 5.0
    private let orbRadius: CGFloat = 28
    private let orbSpeed: CGFloat = 4.0

    // ── 빔 ──
    @State private var beamVisible = false

    // ── 방향 ──
    @State private var targetDir: PushDir = .up
    @State private var arrowBlink = false

    // ── 02.png ──
    @State private var reaperBlur: CGFloat = 3
    @State private var reaperOpacity: Double = 0.55
    @State private var reaperScale: CGFloat = 1.0

    // ── 타이머 ──
    @State private var gameTimer: Timer?
    @State private var phaseTimer: Timer?
    @State private var holdTimer: Timer?

    // ── 화면 ──
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var renderTick: Int = 0
    @State private var gameStarted = false

    // ── 눈 위치 (화면 비율) ──
    private func leftEyePos() -> CGPoint {
        CGPoint(x: screenW * 0.385, y: screenH * 0.345)
    }
    private func rightEyePos() -> CGPoint {
        CGPoint(x: screenW * 0.615, y: screenH * 0.345)
    }
    private let eyeRadius: CGFloat = 32

    // ── 라운드별 파라미터 ──
    private func eyeGlowDuration(_ r: Int) -> ClosedRange<Double> {
        // 눈이 빛나는 대기 시간 (이 안에 누르기 시작해야 함)
        switch r {
        case 0: return 6.0...8.0
        case 1: return 5.0...7.0
        case 2: return 4.0...6.0
        case 3: return 3.5...5.0
        default: return 3.0...4.5
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 02.png ──
                Image("02")
                    .resizable()
                    .scaledToFit()
                    .blur(radius: reaperBlur)
                    .opacity(reaperOpacity)
                    .scaleEffect(reaperScale)
                    .allowsHitTesting(false)

                // ── 왼쪽 눈 glow ──
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(leftEyeGlow * 0.8),
                                Color.red.opacity(leftEyeGlow * 0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 3,
                            endRadius: eyeRadius * 2
                        )
                    )
                    .frame(width: eyeRadius * 4, height: eyeRadius * 4)
                    .scaleEffect(activeEye == .left ? eyePulse : 1.0)
                    .position(leftEyePos())
                    .allowsHitTesting(false)

                // ── 오른쪽 눈 glow ──
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(rightEyeGlow * 0.8),
                                Color.red.opacity(rightEyeGlow * 0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 3,
                            endRadius: eyeRadius * 2
                        )
                    )
                    .frame(width: eyeRadius * 4, height: eyeRadius * 4)
                    .scaleEffect(activeEye == .right ? eyePulse : 1.0)
                    .position(rightEyePos())
                    .allowsHitTesting(false)

                // ── 눈 터치 영역 (eyeGlowing / holding 시) ──
                if phase == .eyeGlowing || phase == .holding {
                    // 왼쪽 눈 터치
                    eyeTouchArea(eye: .left)
                        .position(leftEyePos())

                    // 오른쪽 눈 터치
                    eyeTouchArea(eye: .right)
                        .position(rightEyePos())
                }

                // ── 홀드 프로그레스 링 ──
                if phase == .holding {
                    let pos = activeEye == .left ? leftEyePos() : rightEyePos()
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(Color.green.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: eyeRadius * 2.5, height: eyeRadius * 2.5)
                        .rotationEffect(.degrees(-90))
                        .position(pos)
                        .allowsHitTesting(false)
                }

                // ── 빔 (눈 → 구체) ──
                if beamVisible && orbVisible {
                    let _ = renderTick
                    let eyePos = activeEye == .left ? leftEyePos() : rightEyePos()
                    Path { p in
                        p.move(to: eyePos)
                        p.addLine(to: CGPoint(x: orbX, y: orbY))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.red.opacity(0.5), Color.red.opacity(0.08)],
                            startPoint: .init(
                                x: eyePos.x / max(1, screenW),
                                y: eyePos.y / max(1, screenH)
                            ),
                            endPoint: .init(
                                x: orbX / max(1, screenW),
                                y: orbY / max(1, screenH)
                            )
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .shadow(color: .red.opacity(0.15), radius: 6)
                    .allowsHitTesting(false)
                }

                // ── 구체 ──
                if orbVisible {
                    let _ = renderTick
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.red.opacity(0.35),
                                        Color.red.opacity(0.06),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(orbPulse)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.35, blue: 0.25),
                                        Color(red: 0.75, green: 0.0, blue: 0.0)
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: orbRadius
                                )
                            )
                            .frame(width: orbRadius * 2, height: orbRadius * 2)
                            .shadow(color: .red.opacity(0.5), radius: 10)

                        if orbGrabbed {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .frame(width: orbRadius * 2 + 6, height: orbRadius * 2 + 6)
                        }
                    }
                    .position(x: orbX, y: orbY)
                    .gesture(orbDragGesture)
                }

                // ── 방향 화살표 (orbAlive 시 — 화살표만, 텍스트 없음) ──
                if phase == .orbAlive {
                    directionArrows
                }

                // ── UI 오버레이 ──
                VStack {
                    // 라운드 인디케이터
                    HStack(spacing: 6) {
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
                    .padding(.top, 16)

                    // 밀어내기 제한시간 바
                    if phase == .orbAlive {
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pushTimeLeft < 1.5
                                          ? Color(red: 1.0, green: 0.23, blue: 0.23).opacity(0.8)
                                          : Color.white.opacity(0.35))
                                    .frame(width: barGeo.size.width * max(0, pushTimeLeft / pushTimeLimit), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 30)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // 상태 텍스트
                    Group {
                        if phase == .eyeGlowing {
                            Text("빛나는 눈을 눌러라")
                                .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.23))
                        } else if phase == .holding {
                            Text("누르고 있어라")
                                .foregroundColor(Color.green.opacity(0.8))
                        } else if phase == .evaded {
                            Text("밀어냈다")
                                .foregroundColor(.green)
                        } else if phase == .failed {
                            EmptyView()
                        } else {
                            Text("")
                        }
                    }
                    .font(Font.system(size: 28, weight: .black).width(.condensed))
                    .shadow(color: .red.opacity(phase == .eyeGlowing ? 0.4 : 0), radius: 12)
                    .padding(.bottom, 50)
                }

                // ── 실패 플래시 ──
                if phase == .failed {
                    Color.red.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    Text("봤다")
                        .font(Font.system(size: 56, weight: .black).width(.condensed))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.6), radius: 30)
                }
            }
            .task {
                screenW = geo.size.width
                screenH = geo.size.height
                guard !gameStarted else { return }
                gameStarted = true
                startGame()
            }
            .onDisappear { cleanup() }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 터치 영역
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyeTouchArea(eye: WhichEye) -> some View {
        Circle()
            .fill(Color.white.opacity(0.001)) // 투명 터치 영역
            .frame(width: eyeRadius * 3.5, height: eyeRadius * 3.5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        eyePressed(eye)
                    }
                    .onEnded { _ in
                        eyeReleased()
                    }
            )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 방향 화살표 (화살표만, 텍스트 없음)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var directionArrows: some View {
        ZStack {
            if targetDir == .up {
                arrowView(rotation: 0)
                    .position(x: screenW / 2, y: 50)
            }
            if targetDir == .down {
                arrowView(rotation: 180)
                    .position(x: screenW / 2, y: screenH - 50)
            }
            if targetDir == .left {
                arrowView(rotation: -90)
                    .position(x: 35, y: screenH / 2)
            }
            if targetDir == .right {
                arrowView(rotation: 90)
                    .position(x: screenW - 35, y: screenH / 2)
            }
        }
        .allowsHitTesting(false)
    }

    private func arrowView(rotation: Double) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "chevron.up")
                .font(.system(size: 30, weight: .black))
            Image(systemName: "chevron.up")
                .font(.system(size: 30, weight: .black))
        }
        .foregroundColor(Color.green.opacity(arrowBlink ? 0.9 : 0.15))
        .shadow(color: .green.opacity(arrowBlink ? 0.5 : 0), radius: 12)
        .rotationEffect(.degrees(rotation))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 구체 드래그
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var orbDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard alive, phase == .orbAlive else { return }
                orbGrabbed = true
                orbX = value.location.x
                orbY = value.location.y
            }
            .onEnded { value in
                guard alive, phase == .orbAlive else { return }
                orbGrabbed = false
                orbVX = (value.predictedEndLocation.x - value.location.x) * 0.3
                orbVY = (value.predictedEndLocation.y - value.location.y) * 0.3
                userFlung = true
            }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 게임
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startGame() {
        alive = true
        round = 0
        startArrowBlink()
        startOrbPulse()
        startEyePulse()
        startRound()
    }

    private func startArrowBlink() {
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            arrowBlink = true
        }
    }

    private func startOrbPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            orbPulse = 1.12
        }
    }

    private func startEyePulse() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            eyePulse = 1.15
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startRound() {
        guard alive, round < totalRounds else { return }
        invalidateAll()
        phase = .darkness
        holdProgress = 0
        orbVisible = false
        beamVisible = false
        orbGrabbed = false
        userFlung = false

        withAnimation(.easeOut(duration: 0.3)) {
            leftEyeGlow = 0
            rightEyeGlow = 0
            reaperBlur = 3
            reaperOpacity = 0.55
            reaperScale = 1.0
        }

        // 암전 후 눈 빛남
        let wait = Double.random(in: 0.8...1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
            guard alive, phase == .darkness else { return }
            enterEyeGlowing()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Phase: 눈 빛남
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func enterEyeGlowing() {
        guard alive else { return }
        phase = .eyeGlowing
        holdProgress = 0

        // 랜덤으로 한쪽 눈 선택
        activeEye = Bool.random() ? .left : .right

        // 저승사자 선명해짐
        withAnimation(.easeIn(duration: 0.3)) {
            reaperBlur = 1
            reaperOpacity = 0.75
            reaperScale = 1.05
        }

        // 선택된 눈 빛남
        withAnimation(.easeIn(duration: 0.4)) {
            if activeEye == .left {
                leftEyeGlow = 1.0
                rightEyeGlow = 0.08
            } else {
                rightEyeGlow = 1.0
                leftEyeGlow = 0.08
            }
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()


        // 제한시간 — 이 안에 누르기 시작해야 함
        let limit = Double.random(in: eyeGlowDuration(round))
        phaseTimer?.invalidate()
        let pt = Timer(timeInterval: limit, repeats: false) { [self] _ in
            guard alive, phase == .eyeGlowing else { return }
            // 시간 안에 누르지 못함 → 실패
            hit()
        }
        RunLoop.main.add(pt, forMode: .common)
        phaseTimer = pt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 프레스/릴리즈
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyePressed(_ eye: WhichEye) {
        guard alive else { return }

        if phase == .eyeGlowing {
            if eye == activeEye {
                // 맞는 눈 → 홀드 시작
                phase = .holding
                phaseTimer?.invalidate() // 제한시간 타이머 해제
                startHoldTimer()
            }
            // 틀린 눈은 무시 (반응 없음)
        } else if phase == .holding {
            if eye != activeEye {
                // 홀드 중 다른 눈으로 옮기면 → 프로그레스 리셋
                holdTimer?.invalidate()
                holdProgress = 0
                phase = .eyeGlowing
                // 제한시간 재시작
                let limit = Double.random(in: eyeGlowDuration(round))
                phaseTimer?.invalidate()
                let pt = Timer(timeInterval: limit, repeats: false) { [self] _ in
                    guard alive, phase == .eyeGlowing else { return }
                    hit()
                }
                RunLoop.main.add(pt, forMode: .common)
                phaseTimer = pt
            }
        }
    }

    private func eyeReleased() {
        guard alive else { return }
        if phase == .holding {
            // 손 떼면 홀드 리셋 → 다시 eyeGlowing
            holdTimer?.invalidate()
            holdProgress = 0
            phase = .eyeGlowing

            let limit = Double.random(in: eyeGlowDuration(round))
            phaseTimer?.invalidate()
            let pt = Timer(timeInterval: limit, repeats: false) { [self] _ in
                guard alive, phase == .eyeGlowing else { return }
                hit()
            }
            RunLoop.main.add(pt, forMode: .common)
            phaseTimer = pt
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 홀드 타이머 (3초)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startHoldTimer() {
        holdTimer?.invalidate()
        let startTime = Date()
        let ht = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            guard alive, phase == .holding else {
                holdTimer?.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            holdProgress = min(1.0, elapsed / holdDuration)

            // 진동 피드백 (25%, 50%, 75%)
            if holdProgress > 0.24 && holdProgress < 0.27 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if holdProgress > 0.49 && holdProgress < 0.52 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            if holdProgress > 0.74 && holdProgress < 0.77 {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }

            if holdProgress >= 1.0 {
                holdTimer?.invalidate()
                // 3초 완료 → 구체 발사!
                spawnOrb()
            }
        }
        RunLoop.main.add(ht, forMode: .common)
        holdTimer = ht
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 구체 발사
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func spawnOrb() {
        guard alive else { return }
        phase = .orbAlive
        beamVisible = true
        orbVisible = true
        orbGrabbed = false
        userFlung = false
        pushTimeLeft = pushTimeLimit

        // 구체 초기 위치 = 활성 눈 위치
        let eyePos = activeEye == .left ? leftEyePos() : rightEyePos()
        orbX = eyePos.x
        orbY = eyePos.y

        // 랜덤 방향
        targetDir = PushDir.allCases.randomElement()!

        // 초기 속도 — 대상 방향 반대로
        switch targetDir {
        case .up:
            orbVX = CGFloat.random(in: -orbSpeed...orbSpeed)
            orbVY = CGFloat.random(in: 1.0...orbSpeed)
        case .down:
            orbVX = CGFloat.random(in: -orbSpeed...orbSpeed)
            orbVY = CGFloat.random(in: -orbSpeed...(-1.0))
        case .left:
            orbVX = CGFloat.random(in: 1.0...orbSpeed)
            orbVY = CGFloat.random(in: -orbSpeed...orbSpeed)
        case .right:
            orbVX = CGFloat.random(in: -orbSpeed...(-1.0))
            orbVY = CGFloat.random(in: -orbSpeed...orbSpeed)
        }

        // 눈 glow 연출
        withAnimation(.easeOut(duration: 0.2)) {
            leftEyeGlow = 0.1
            rightEyeGlow = 0.1
        }

        audioEngine?.playZamkeOnce()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.easeOut(duration: 0.05)) { reaperScale = 1.1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            withAnimation(.easeOut(duration: 0.2)) { reaperScale = 1.05 }
        }

        // 게임 루프
        gameTimer?.invalidate()
        let startTime = Date()
        let t = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive, phase == .orbAlive else { return }

            renderTick &+= 1
            pushTimeLeft = max(0, pushTimeLimit - Date().timeIntervalSince(startTime))

            if !orbGrabbed {
                orbX += orbVX
                orbY += orbVY

                let m: CGFloat = orbRadius

                // 벽 체크
                if orbY < m {
                    if targetDir == .up && userFlung {
                        if orbY < -orbRadius { gameTimer?.invalidate(); orbPushedOut(); return }
                    } else { orbY = m; orbVY = abs(orbVY); userFlung = false }
                }
                if orbY > screenH - m {
                    if targetDir == .down && userFlung {
                        if orbY > screenH + orbRadius { gameTimer?.invalidate(); orbPushedOut(); return }
                    } else { orbY = screenH - m; orbVY = -abs(orbVY); userFlung = false }
                }
                if orbX < m {
                    if targetDir == .left && userFlung {
                        if orbX < -orbRadius { gameTimer?.invalidate(); orbPushedOut(); return }
                    } else { orbX = m; orbVX = abs(orbVX); userFlung = false }
                }
                if orbX > screenW - m {
                    if targetDir == .right && userFlung {
                        if orbX > screenW + orbRadius { gameTimer?.invalidate(); orbPushedOut(); return }
                    } else { orbX = screenW - m; orbVX = -abs(orbVX); userFlung = false }
                }

                // 미세 변동
                orbVX += CGFloat.random(in: -0.08...0.08)
                orbVY += CGFloat.random(in: -0.08...0.08)

                // 속도 제한
                let maxSpd: CGFloat = 5.5 + CGFloat(round) * 0.5
                let spd = sqrt(orbVX * orbVX + orbVY * orbVY)
                if spd > maxSpd {
                    orbVX = orbVX / spd * maxSpd
                    orbVY = orbVY / spd * maxSpd
                }
                if spd < 1.5 {
                    switch targetDir {
                    case .up:    orbVY += 0.4
                    case .down:  orbVY -= 0.4
                    case .left:  orbVX += 0.4
                    case .right: orbVX -= 0.4
                    }
                }
            } else {
                orbVX = 0; orbVY = 0
            }

            if pushTimeLeft <= 0 {
                gameTimer?.invalidate()
                hit()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        gameTimer = t
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 밀어냄 성공
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func orbPushedOut() {
        guard alive else { return }
        phase = .evaded
        beamVisible = false
        orbVisible = false
        round += 1

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()


        if round >= totalRounds {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                guard alive else { return }
                withAnimation(.easeOut(duration: 0.8)) {
                    reaperOpacity = 0; reaperBlur = 15
                    leftEyeGlow = 0; rightEyeGlow = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                guard alive else { return }
                alive = false
                onResult(.success)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                guard alive else { return }
                startRound()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 실패
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func hit() {
        guard alive else { return }
        phase = .failed
        beamVisible = false
        orbVisible = false
        invalidateAll()

        withAnimation(.easeIn(duration: 0.05)) {
            reaperScale = 1.25; reaperOpacity = 0.95
            leftEyeGlow = 1.0; rightEyeGlow = 1.0
        }

        // 실패 음향 폭풍
        audioEngine?.fireFailureBlast()

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
        }

        round = max(0, round - 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [self] in
            guard alive else { return }
            withAnimation(.easeOut(duration: 0.3)) { reaperScale = 1.0 }
            startRound()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 정리
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func invalidateAll() {
        gameTimer?.invalidate()
        phaseTimer?.invalidate()
        holdTimer?.invalidate()
    }

    private func cleanup() {
        alive = false
        invalidateAll()
    }
}
