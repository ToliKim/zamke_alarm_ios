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
//  3라운드. 라운드마다 눈 전환 빨라짐, 시간 제한 줄어듦.
//  도중 1~2회 수학 문제가 랜덤으로 돌출.
//
//  ⚠️ 안정성:
//  - .task {} 사용
//  - gameStarted 플래그
//  - onDisappear cleanup
//  - CoreMotion 사용 안 함
//

import SwiftUI
import AudioToolbox

// ── 수학 문제 모델 ──
private struct MathProblem {
    let question: String
    let answer: Int
    let options: [Int]
}

@MainActor
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
    private let totalRounds = 3

    // ── 눈 ──
    @State private var activeEye: WhichEye = .left
    @State private var holdProgress: Double = 0        // 0~1
    // 라운드별 홀드 시간 — 점점 길어짐
    private var holdDuration: Double {
        switch round {
        case 0: return 2.5
        case 1: return 3.0
        default: return 3.5
        }
    }
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
    // 라운드별 밀어내기 시간 — 점점 짧아짐
    private var pushTimeLimit: Double {
        switch round {
        case 0: return 5.0
        case 1: return 4.0
        default: return 3.0
        }
    }
    private let orbRadius: CGFloat = 28
    // 라운드별 구체 초기속도 — 점점 빨라짐
    private var orbSpeed: CGFloat {
        switch round {
        case 0: return 3.5
        case 1: return 5.0
        default: return 6.5
        }
    }

    // ── 빔 ──
    @State private var beamVisible = false

    // ── 방향 ──
    @State private var targetDir: PushDir = .up
    @State private var arrowBlink = false

    // ── 02.png ──
    @State private var reaperBlur: CGFloat = 3
    @State private var reaperOpacity: Double = 0.55
    @State private var reaperScale: CGFloat = 1.0

    // ── 수학 문제 ──
    @State private var showingMath = false
    @State private var currentMath: MathProblem? = nil
    @State private var mathCount = 0
    @State private var maxMathCount = 0
    @State private var mathRounds: Set<Int> = []   // 수학 문제가 나올 라운드
    @State private var mathWrongFlash = false

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

    // ── 라운드별 파라미터 (3라운드, 높은 난이도) ──
    private func eyeGlowDuration(_ r: Int) -> ClosedRange<Double> {
        switch r {
        case 0: return 4.5...6.0
        case 1: return 3.0...4.5
        default: return 2.0...3.5
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 수학 문제 생성
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func generateMath() -> MathProblem {
        let type = Int.random(in: 0...2)
        var a: Int, b: Int, ans: Int, q: String
        switch type {
        case 0:
            a = Int.random(in: 12...55)
            b = Int.random(in: 8...45)
            ans = a + b
            q = "\(a) + \(b)"
        case 1:
            a = Int.random(in: 25...80)
            b = Int.random(in: 5...(a - 1))
            ans = a - b
            q = "\(a) - \(b)"
        default:
            a = Int.random(in: 3...12)
            b = Int.random(in: 2...9)
            ans = a * b
            q = "\(a) × \(b)"
        }

        var opts = [ans]
        while opts.count < 4 {
            let offset = Int.random(in: 1...10) * (Bool.random() ? 1 : -1)
            let wrong = ans + offset
            if wrong != ans && !opts.contains(wrong) && wrong >= 0 {
                opts.append(wrong)
            }
        }
        opts.shuffle()
        return MathProblem(question: q, answer: ans, options: opts)
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

                // ── 눈 터치 영역 (eyeGlowing / holding 시 & 수학 아닐 때) ──
                if (phase == .eyeGlowing || phase == .holding) && !showingMath {
                    eyeTouchArea(eye: .left)
                        .position(leftEyePos())
                    eyeTouchArea(eye: .right)
                        .position(rightEyePos())
                }

                // ── 홀드 프로그레스 링 ──
                if phase == .holding && !showingMath {
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
                if beamVisible && orbVisible && !showingMath {
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
                if orbVisible && !showingMath {
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

                // ── 방향 화살표 (orbAlive 시) ──
                if phase == .orbAlive && !showingMath {
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
                    if phase == .orbAlive && !showingMath {
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
                    if !showingMath {
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

                // ── 수학 문제 오버레이 ──
                if showingMath {
                    mathOverlay
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
    // MARK: - 수학 문제 오버레이
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var mathOverlay: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("풀어라")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(Color(red: 1, green: 0.12, blue: 0.08))
                    .shadow(color: .red.opacity(0.5), radius: 15)

                if let math = currentMath {
                    Text(math.question)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.2), radius: 8)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ], spacing: 14) {
                        ForEach(math.options, id: \.self) { opt in
                            Button {
                                mathAnswered(opt)
                            } label: {
                                Text("\(opt)")
                                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                }
            }

            if mathWrongFlash {
                Color.red.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 수학 문제 로직
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func triggerMath() {
        guard alive, !showingMath else { return }
        mathCount += 1
        currentMath = generateMath()
        showingMath = true
        mathWrongFlash = false

        // 현재 진행 중인 타이머 일시 정지
        phaseTimer?.invalidate()
        holdTimer?.invalidate()
        gameTimer?.invalidate()

        AudioServicesPlaySystemSound(1322)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func mathAnswered(_ choice: Int) {
        guard let math = currentMath else { return }

        if choice == math.answer {
            // 정답 → 계속 진행
            showingMath = false
            currentMath = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            resumeAfterMath()
        } else {
            // 오답 → 페널티
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioEngine?.fireFailureBlast()

            mathWrongFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                mathWrongFlash = false
            }

            // 오답 시 현재 라운드 실패 처리
            showingMath = false
            currentMath = nil
            hit()
        }
    }

    private func resumeAfterMath() {
        // 수학 문제 전 상태에 따라 재개
        switch phase {
        case .darkness:
            // 다시 darkness → eyeGlowing 전환 대기
            let wait = Double.random(in: 0.5...1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
                guard alive, phase == .darkness else { return }
                enterEyeGlowing()
            }
        case .eyeGlowing:
            // eyeGlowing 타이머 재시작
            let limit = Double.random(in: eyeGlowDuration(round))
            phaseTimer?.invalidate()
            let pt = Timer(timeInterval: limit, repeats: false) { [self] _ in
                guard alive, phase == .eyeGlowing else { return }
                hit()
            }
            RunLoop.main.add(pt, forMode: .common)
            phaseTimer = pt
        case .holding:
            // 홀드 타이머 재시작 (프로그레스 유지)
            startHoldTimer()
        case .orbAlive:
            // 구체 게임루프 재시작
            restartOrbLoop()
        default:
            break
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 터치 영역
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyeTouchArea(eye: WhichEye) -> some View {
        Circle()
            .fill(Color.white.opacity(0.001))
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
    // MARK: - 방향 화살표
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
                guard alive, phase == .orbAlive, !showingMath else { return }
                orbGrabbed = true
                orbX = value.location.x
                orbY = value.location.y
            }
            .onEnded { value in
                guard alive, phase == .orbAlive, !showingMath else { return }
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

        // 수학 문제 스케줄: 1~2회, 랜덤 라운드 선택
        maxMathCount = Int.random(in: 1...2)
        mathCount = 0
        var possibleRounds = Array(0..<totalRounds)
        possibleRounds.shuffle()
        mathRounds = Set(possibleRounds.prefix(maxMathCount))

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
        showingMath = false
        currentMath = nil

        withAnimation(.easeOut(duration: 0.3)) {
            leftEyeGlow = 0
            rightEyeGlow = 0
            reaperBlur = 3
            reaperOpacity = 0.55
            reaperScale = 1.0
        }

        // 이 라운드에 수학 문제가 있으면 먼저 출제
        if mathRounds.contains(round) && mathCount < maxMathCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard alive, phase == .darkness else { return }
                triggerMath()
            }
        } else {
            // 수학 없으면 바로 진행
            let wait = Double.random(in: 0.8...1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
                guard alive, phase == .darkness else { return }
                enterEyeGlowing()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Phase: 눈 빛남
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func enterEyeGlowing() {
        guard alive else { return }
        phase = .eyeGlowing
        holdProgress = 0

        activeEye = Bool.random() ? .left : .right

        withAnimation(.easeIn(duration: 0.3)) {
            reaperBlur = 1
            reaperOpacity = 0.75
            reaperScale = 1.05
        }

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
        AudioServicesPlaySystemSound(1322)

        let limit = Double.random(in: eyeGlowDuration(round))
        phaseTimer?.invalidate()
        let pt = Timer(timeInterval: limit, repeats: false) { [self] _ in
            guard alive, phase == .eyeGlowing else { return }
            hit()
        }
        RunLoop.main.add(pt, forMode: .common)
        phaseTimer = pt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 프레스/릴리즈
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyePressed(_ eye: WhichEye) {
        guard alive, !showingMath else { return }

        if phase == .eyeGlowing {
            if eye == activeEye {
                phase = .holding
                phaseTimer?.invalidate()
                startHoldTimer()
            }
        } else if phase == .holding {
            if eye != activeEye {
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
    }

    private func eyeReleased() {
        guard alive, !showingMath else { return }
        if phase == .holding {
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
    // MARK: - 홀드 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startHoldTimer() {
        holdTimer?.invalidate()
        let startTime = Date()
        let startProgress = holdProgress
        let ht = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            guard alive, phase == .holding, !showingMath else {
                if showingMath { holdTimer?.invalidate() }
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            holdProgress = min(1.0, startProgress + elapsed / holdDuration)

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

        let eyePos = activeEye == .left ? leftEyePos() : rightEyePos()
        orbX = eyePos.x
        orbY = eyePos.y

        targetDir = PushDir.allCases.randomElement()!

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

        startOrbLoop()
    }

    private func startOrbLoop() {
        gameTimer?.invalidate()
        let startTime = Date()
        let t = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive, phase == .orbAlive, !showingMath else {
                if showingMath { gameTimer?.invalidate() }
                return
            }

            renderTick &+= 1
            pushTimeLeft = max(0, pushTimeLimit - Date().timeIntervalSince(startTime))

            if !orbGrabbed {
                orbX += orbVX
                orbY += orbVY

                let m: CGFloat = orbRadius

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

                orbVX += CGFloat.random(in: -0.08...0.08)
                orbVY += CGFloat.random(in: -0.08...0.08)

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

    // 수학 후 구체 루프 재시작
    private func restartOrbLoop() {
        startOrbLoop()
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
        AudioServicesPlaySystemSound(1057)

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

        audioEngine?.fireFailureBlast()
        AudioServicesPlaySystemSound(1322)
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
