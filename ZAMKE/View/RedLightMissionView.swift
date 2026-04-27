//
//  RedLightMissionView.swift
//  ZAMKE
//
//  미션 2: 눈빛 연타 — "붉은 눈동자를 찍어라"
//
//  ── 핵심 메카닉 ──
//  02 저승사자 배경 위에 움직이는 눈동자가 랜덤 등장.
//  붉은 눈동자를 터치하면 카운트 +1.
//  하얀 눈동자를 터치하면 카운트 -2.
//  30개 붉은 눈동자를 찍으면 클리어. 단일 라운드.
//  도중 1~2회 수학 문제가 돌출 → 풀어야 계속.
//
//  ── 공포 장치 ──
//  1. 빨간 비네트 맥동
//  2. 눈동자가 움직이며 나타났다 사라짐
//  3. 하얀 눈동자 함정
//  4. 수학 문제 긴장감
//

import SwiftUI
import AudioToolbox

// ── 눈빛 모델 ──
private struct EyeFlash: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat          // 이동 속도 x
    var vy: CGFloat          // 이동 속도 y
    var size: CGFloat
    var isRed: Bool          // true=붉은(정답), false=하얀(함정)
    var opacity: Double = 0
    var hit: Bool = false
}

// ── 수학 문제 모델 ──
private struct MathProblem {
    let question: String
    let answer: Int
    let options: [Int]
}

@MainActor
struct RedLightMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 페이즈 ──
    enum Phase: Sendable {
        case darkness
        case playing
        case jumpScare
        case destroying
        case cleared
    }

    @State private var phase: Phase = .darkness
    @State private var alive = true

    // ── 단일 라운드 ──
    private let requiredHits = 20

    // ── 눈빛 ──
    @State private var eyeFlashes: [EyeFlash] = []
    @State private var hitCount: Int = 0
    @State private var hitFlashOpacity: Double = 0  // 성공 터치 피드백

    // ── 02.png 비주얼 ──
    @State private var imgScale: CGFloat = 1.0
    @State private var imgBlur: CGFloat = 8
    @State private var imgOpacity: Double = 0
    @State private var redGlow: Double = 0
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0

    // ── 비네트 맥동 ──
    @State private var vignetteOpacity: Double = 0
    @State private var heartbeatPhase: Bool = false

    // ── 점프스케어 ──
    @State private var scareScale: CGFloat = 1.0
    @State private var scareOpacity: Double = 0
    @State private var screenFlashRed: Double = 0
    @State private var scareShakeX: CGFloat = 0
    @State private var scareShakeY: CGFloat = 0
    @State private var scareShakeTimer: Timer?

    // ── 파괴 연출 ──
    @State private var destroyScale: CGFloat = 1.0
    @State private var destroyOpacity: Double = 1.0
    @State private var destroyRotation: Double = 0
    @State private var flashWhite: Double = 0

    // ── 타이머 ──
    @State private var roundTimer: Timer?
    @State private var spawnTimer: Timer?
    @State private var shakeTimer: Timer?
    @State private var heartTimer: Timer?
    @State private var moveTimer: Timer?
    @State private var timeLeft: Double = 0
    private let timeLimit: Double = 40.0

    // ── 수학 문제 ──
    @State private var showingMath = false
    @State private var currentMath: MathProblem? = nil
    @State private var mathCount = 0
    @State private var maxMathCount = 0
    @State private var mathWrongFlash = false

    // ── 화면 ──
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var gameStarted = false

    // ── 스폰 파라미터 (높은 난이도) ──
    private let spawnIntervalRange: ClosedRange<Double> = 0.5...1.0
    private let flashLifetimeRange: ClosedRange<Double> = 1.0...2.2
    private let whiteChance: Double = 0.28
    private let maxOnScreen = 7

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // ── 02.png: 저승사자 배경 ──
                if phase == .playing || showingMath {
                    Image("02")
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenW, height: screenH)
                        .scaleEffect(imgScale)
                        .blur(radius: imgBlur)
                        .opacity(imgOpacity)
                        .offset(x: shakeX, y: shakeY)
                        .colorMultiply(Color(
                            red: 1.0,
                            green: max(0.1, 1.0 - redGlow * 0.9),
                            blue: max(0.05, 1.0 - redGlow * 0.95)
                        ))
                        .clipped()
                        .allowsHitTesting(false)
                }

                // ── 눈빛들 ──
                if phase == .playing && !showingMath {
                    ForEach(eyeFlashes) { flash in
                        if !flash.hit {
                            eyeFlashView(flash)
                                .position(x: flash.x, y: flash.y)
                                .opacity(flash.opacity)
                                .onTapGesture { flashTapped(flash) }
                        }
                    }
                }

                // ── 히트 플래시 (초록 = 성공) ──
                if hitFlashOpacity > 0.01 {
                    Color.green.opacity(hitFlashOpacity * 0.15)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // ── 빨간 비네트 맥동 ──
                if vignetteOpacity > 0.01 {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.4),
                            Color(red: 0.3, green: 0, blue: 0).opacity(vignetteOpacity)
                        ]),
                        center: .center,
                        startRadius: screenW * 0.15,
                        endRadius: screenW * 0.75
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // ── 점프스케어 ──
                if phase == .jumpScare {
                    Image("02")
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenW, height: screenH)
                        .scaleEffect(scareScale)
                        .offset(x: scareShakeX, y: scareShakeY)
                        .opacity(scareOpacity)
                        .colorMultiply(Color(red: 1.0, green: 0.04, blue: 0.01))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // ── 파괴 연출 ──
                if phase == .destroying {
                    Image("02")
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenW, height: screenH)
                        .scaleEffect(destroyScale)
                        .opacity(destroyOpacity)
                        .rotationEffect(.degrees(destroyRotation))
                        .blur(radius: CGFloat((1.0 - destroyOpacity) * 12))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // ── 붉은 플래시 ──
                if screenFlashRed > 0.01 {
                    Color.red.opacity(screenFlashRed)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // ── 흰 플래시 ──
                if flashWhite > 0.01 {
                    Color.white.opacity(flashWhite)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // ── UI 오버레이 ──
                VStack(spacing: 0) {
                    // 타이머 바
                    if phase == .playing || showingMath {
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(timeLeft < 10.0
                                          ? Color.red.opacity(0.8)
                                          : Color.white.opacity(0.35))
                                    .frame(width: barGeo.size.width * max(0, timeLeft / timeLimit), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                    }

                    Spacer()

                    // 중앙: 카운터
                    if phase == .playing && !showingMath {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text("\(hitCount)")
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.9))
                                    .shadow(color: .green.opacity(0.5), radius: 10)

                                Text("/ \(requiredHits)")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }

                            Text("붉은 눈동자를 찍어라")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 1.0, green: 0.1, blue: 0.05))
                                .shadow(color: .red.opacity(0.6), radius: 15)
                        }
                        .allowsHitTesting(false)
                    }

                    if phase == .destroying {
                        Text("소멸")
                            .font(Font.system(size: 38, weight: .black).width(.condensed))
                            .foregroundColor(.green.opacity(0.7))
                            .shadow(color: .green.opacity(0.4), radius: 15)
                    }

                    Spacer()
                    Spacer().frame(height: 40)
                }
                .allowsHitTesting(false)

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
    // MARK: - 눈빛 뷰
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyeFlashView(_ flash: EyeFlash) -> some View {
        ZStack {
            // 외부 glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (flash.isRed
                                ? Color.red : Color.white)
                                .opacity(0.6),
                            (flash.isRed
                                ? Color.red : Color.white)
                                .opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: flash.size * 1.5
                    )
                )
                .frame(width: flash.size * 3, height: flash.size * 3)

            // 핵심 눈빛
            Circle()
                .fill(
                    RadialGradient(
                        colors: flash.isRed
                            ? [
                                Color(red: 1.0, green: 0.3, blue: 0.2),
                                Color(red: 0.8, green: 0.05, blue: 0.05),
                                Color(red: 0.4, green: 0.02, blue: 0.02)
                              ]
                            : [
                                Color(white: 1.0),
                                Color(white: 0.85),
                                Color(white: 0.6)
                              ],
                        center: .center,
                        startRadius: 2,
                        endRadius: flash.size
                    )
                )
                .frame(width: flash.size * 2, height: flash.size * 2)
                .shadow(color: flash.isRed
                        ? .red.opacity(0.6) : .white.opacity(0.5),
                        radius: 12)

            // 동공
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: flash.size * 0.5, height: flash.size * 0.7)

            // 하이라이트
            Circle()
                .fill(Color.white.opacity(flash.isRed ? 0.7 : 0.3))
                .frame(width: flash.size * 0.2, height: flash.size * 0.2)
                .offset(x: flash.size * 0.15, y: -flash.size * 0.15)
        }
        .contentShape(Circle().size(width: flash.size * 3.5, height: flash.size * 3.5))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 수학 문제 오버레이
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var mathOverlay: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // 제목
                Text("풀어라")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(Color(red: 1, green: 0.12, blue: 0.08))
                    .shadow(color: .red.opacity(0.5), radius: 15)

                if let math = currentMath {
                    // 수식
                    Text(math.question)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.2), radius: 8)

                    // 4지선다
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

            // 오답 플래시
            if mathWrongFlash {
                Color.red.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈빛 터치
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func flashTapped(_ flash: EyeFlash) {
        guard alive, phase == .playing, !showingMath else { return }
        guard let idx = eyeFlashes.firstIndex(where: { $0.id == flash.id }) else { return }
        guard !eyeFlashes[idx].hit else { return }

        eyeFlashes[idx].hit = true

        if flash.isRed {
            // ── 붉은 눈동자 → 카운트 +1 ──
            hitCount += 1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // 초록 플래시
            hitFlashOpacity = 0.6
            withAnimation(.easeOut(duration: 0.2)) { hitFlashOpacity = 0 }

            // 클리어 체크
            if hitCount >= requiredHits {
                missionCleared()
            }
        } else {
            // ── 하얀 눈동자 → 카운트 -2 + 경고 ──
            hitCount = max(0, hitCount - 2)

            // 경고음: 짧은 시스템 경고 + 실패 사운드
            AudioServicesPlaySystemSound(1322)
            audioEngine?.fireFailureBlast()

            // 연타 진동: 3연속으로 강하게
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }

            // 붉은 플래시 (더 강하게)
            screenFlashRed = 0.65
            withAnimation(.easeOut(duration: 0.35)) { screenFlashRed = 0 }

            // 흔들림 (더 크게, 2단계)
            shakeX = CGFloat.random(in: -14...14)
            shakeY = CGFloat.random(in: -8...8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                shakeX = CGFloat.random(in: -10...10)
                shakeY = CGFloat.random(in: -6...6)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                shakeX = 0; shakeY = 0
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 수학 문제 로직
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

    private func scheduleMathProblems() {
        maxMathCount = Int.random(in: 1...2)
        mathCount = 0

        // 첫 번째: 10~22초
        let t1 = Double.random(in: 10...22)
        DispatchQueue.main.asyncAfter(deadline: .now() + t1) { [self] in
            guard alive, phase == .playing, !showingMath, mathCount < maxMathCount else { return }
            triggerMath()
        }

        if maxMathCount == 2 {
            // 두 번째: 32~48초
            let t2 = Double.random(in: 32...48)
            DispatchQueue.main.asyncAfter(deadline: .now() + t2) { [self] in
                guard alive, phase == .playing, !showingMath, mathCount < maxMathCount else { return }
                triggerMath()
            }
        }
    }

    private func triggerMath() {
        guard alive, phase == .playing else { return }
        mathCount += 1
        currentMath = generateMath()
        showingMath = true
        mathWrongFlash = false

        // 게임 일시 정지
        pauseGameplay()

        AudioServicesPlaySystemSound(1322)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func mathAnswered(_ choice: Int) {
        guard let math = currentMath else { return }

        if choice == math.answer {
            // 정답 → 계속
            showingMath = false
            currentMath = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            resumeGameplay()
        } else {
            // 오답 → -5초 페널티 + 다시 풀기
            timeLeft = max(0, timeLeft - 5.0)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioEngine?.fireFailureBlast()

            mathWrongFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                mathWrongFlash = false
            }

            // 시간 다 떨어지면 실패
            if timeLeft <= 0 {
                showingMath = false
                currentMath = nil
                roundFailed()
            }
        }
    }

    private func pauseGameplay() {
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        // spawnTimer는 DispatchQueue 기반이라 showingMath 체크로 방어
    }

    private func resumeGameplay() {
        startRoundTimer()
        startMoveTimer()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 게임 시작
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startGame() {
        alive = true
        hitCount = 0
        startRound()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 시작
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startRound() {
        invalidateAll()
        phase = .darkness
        hitCount = 0
        eyeFlashes = []
        hitFlashOpacity = 0
        imgOpacity = 0
        imgScale = 1.0
        imgBlur = 8
        redGlow = 0
        shakeX = 0
        shakeY = 0
        vignetteOpacity = 0
        screenFlashRed = 0
        scareOpacity = 0
        flashWhite = 0
        showingMath = false
        currentMath = nil

        let wait = Double.random(in: 1.0...2.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
            guard alive, phase == .darkness else { return }
            enterPlaying()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 플레이 진입
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func enterPlaying() {
        guard alive else { return }
        phase = .playing
        timeLeft = timeLimit

        withAnimation(.easeIn(duration: 0.2)) {
            imgOpacity = 0.7
            imgBlur = 2
            imgScale = 1.25
            redGlow = 0.6
        }

        withAnimation(.easeIn(duration: 0.3)) {
            vignetteOpacity = 0.6
        }

        AudioServicesPlaySystemSound(1322)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        startShake()
        startHeartbeat()
        startRoundTimer()
        startSpawner()
        startMoveTimer()
        scheduleMathProblems()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈빛 스포너
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startSpawner() {
        func scheduleNext() {
            guard alive, phase == .playing else { return }
            let delay = Double.random(in: spawnIntervalRange)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                guard alive, phase == .playing else { return }
                if !showingMath {
                    spawnEyeFlash()
                }
                scheduleNext()
            }
        }

        // 첫 눈빛
        spawnEyeFlash()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            guard alive, phase == .playing else { return }
            spawnEyeFlash()
            scheduleNext()
        }
    }

    private func spawnEyeFlash() {
        guard alive, phase == .playing, !showingMath else { return }

        let activeCount = eyeFlashes.filter { !$0.hit && $0.opacity > 0.01 }.count
        guard activeCount < maxOnScreen else { return }

        let margin: CGFloat = 60
        let isWhite = Double.random(in: 0...1) < whiteChance
        let size: CGFloat = CGFloat.random(in: 18...32)

        // 랜덤 이동 속도 (빠르게 움직임)
        let speed: CGFloat = CGFloat.random(in: 0.8...2.0)
        let angle = CGFloat.random(in: 0...(2 * .pi))

        let flash = EyeFlash(
            x: CGFloat.random(in: margin...(screenW - margin)),
            y: CGFloat.random(in: 100...(screenH - 160)),
            vx: cos(angle) * speed,
            vy: sin(angle) * speed,
            size: size,
            isRed: !isWhite,
            opacity: 0,
            hit: false
        )

        eyeFlashes.append(flash)
        let flashID = flash.id

        // 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            if let idx = eyeFlashes.firstIndex(where: { $0.id == flashID }) {
                withAnimation(.easeIn(duration: 0.25)) {
                    eyeFlashes[idx].opacity = 1.0
                }
            }
        }

        // 생존 시간 후 자동 소멸
        let lifetime = Double.random(in: flashLifetimeRange)
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { [self] in
            guard let idx = eyeFlashes.firstIndex(where: { $0.id == flashID }) else { return }
            guard !eyeFlashes[idx].hit else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                eyeFlashes[idx].opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                eyeFlashes.removeAll { $0.id == flashID }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈빛 이동 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startMoveTimer() {
        moveTimer?.invalidate()
        let mt = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive, phase == .playing, !showingMath else { return }

            let margin: CGFloat = 40
            for i in eyeFlashes.indices {
                guard !eyeFlashes[i].hit else { continue }

                eyeFlashes[i].x += eyeFlashes[i].vx
                eyeFlashes[i].y += eyeFlashes[i].vy

                // 벽 바운스
                if eyeFlashes[i].x < margin {
                    eyeFlashes[i].x = margin
                    eyeFlashes[i].vx = abs(eyeFlashes[i].vx)
                } else if eyeFlashes[i].x > screenW - margin {
                    eyeFlashes[i].x = screenW - margin
                    eyeFlashes[i].vx = -abs(eyeFlashes[i].vx)
                }
                if eyeFlashes[i].y < 80 {
                    eyeFlashes[i].y = 80
                    eyeFlashes[i].vy = abs(eyeFlashes[i].vy)
                } else if eyeFlashes[i].y > screenH - 140 {
                    eyeFlashes[i].y = screenH - 140
                    eyeFlashes[i].vy = -abs(eyeFlashes[i].vy)
                }

                // 미세 방향 변동
                eyeFlashes[i].vx += CGFloat.random(in: -0.03...0.03)
                eyeFlashes[i].vy += CGFloat.random(in: -0.03...0.03)

                // 속도 제한
                let maxSpd: CGFloat = 2.5
                let spd = sqrt(eyeFlashes[i].vx * eyeFlashes[i].vx + eyeFlashes[i].vy * eyeFlashes[i].vy)
                if spd > maxSpd {
                    eyeFlashes[i].vx = eyeFlashes[i].vx / spd * maxSpd
                    eyeFlashes[i].vy = eyeFlashes[i].vy / spd * maxSpd
                }
            }
        }
        RunLoop.main.add(mt, forMode: .common)
        moveTimer = mt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startRoundTimer() {
        roundTimer?.invalidate()
        let rt = Timer(timeInterval: 0.1, repeats: true) { [self] _ in
            guard alive, phase == .playing, !showingMath else {
                if phase != .playing { roundTimer?.invalidate() }
                return
            }
            timeLeft -= 0.1
            if timeLeft <= 0 {
                roundTimer?.invalidate()
                roundFailed()
            }
        }
        RunLoop.main.add(rt, forMode: .common)
        roundTimer = rt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심장 박동
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startHeartbeat() {
        heartTimer?.invalidate()
        let interval = 0.55

        let ht = Timer(timeInterval: interval, repeats: true) { [self] _ in
            guard alive, phase == .playing else {
                heartTimer?.invalidate()
                return
            }
            heartbeatPhase.toggle()
            if heartbeatPhase {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            withAnimation(.easeInOut(duration: interval * 0.4)) {
                vignetteOpacity = heartbeatPhase ? 0.8 : 0.5
                redGlow = heartbeatPhase ? 0.75 : 0.5
            }
        }
        RunLoop.main.add(ht, forMode: .common)
        heartTimer = ht
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 미세 떨림
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startShake() {
        shakeTimer?.invalidate()
        let intensity: CGFloat = 1.0
        let st = Timer(timeInterval: 0.06, repeats: true) { [self] _ in
            guard alive, phase == .playing else {
                shakeTimer?.invalidate()
                return
            }
            shakeX = CGFloat.random(in: -intensity...intensity)
            shakeY = CGFloat.random(in: -intensity * 0.3...intensity * 0.3)
        }
        RunLoop.main.add(st, forMode: .common)
        shakeTimer = st
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 미션 클리어
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func missionCleared() {
        invalidateAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard alive else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                imgOpacity = 0
                imgBlur = 15
                vignetteOpacity = 0
            }
            for i in eyeFlashes.indices {
                eyeFlashes[i].opacity = 0
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            guard alive else { return }
            destroyReaper()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 실패 → 점프스케어
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundFailed() {
        guard alive else { return }
        phase = .jumpScare
        invalidateAll()

        scareScale = 1.8
        scareOpacity = 1.0
        screenFlashRed = 0.7
        imgOpacity = 0
        vignetteOpacity = 0

        audioEngine?.fireWarning()
        audioEngine?.fireAjaeng()
        audioEngine?.playZamkeOnce()
        audioEngine?.fireFailureBlast()
        AudioServicesPlaySystemSound(1322)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        withAnimation(.easeIn(duration: 0.2)) {
            scareScale = 2.5
            screenFlashRed = 0.85
        }

        scareShakeTimer?.invalidate()
        let sst = Timer(timeInterval: 0.04, repeats: true) { [self] _ in
            scareShakeX = CGFloat.random(in: -18...18)
            scareShakeY = CGFloat.random(in: -12...12)
        }
        RunLoop.main.add(sst, forMode: .common)
        scareShakeTimer = sst

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            guard alive else { return }
            scareShakeTimer?.invalidate()
            scareShakeX = 0; scareShakeY = 0
            withAnimation(.easeOut(duration: 0.5)) {
                scareOpacity = 0
                screenFlashRed = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                guard alive else { return }
                startRound()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 저승사자 파괴
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func destroyReaper() {
        guard alive else { return }
        phase = .destroying

        destroyScale = 1.3
        destroyOpacity = 1.0
        destroyRotation = 0
        flashWhite = 0

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            guard alive else { return }
            AudioServicesPlaySystemSound(1521)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.easeIn(duration: 0.1)) { flashWhite = 0.95 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
            guard alive else { return }
            withAnimation(.easeOut(duration: 0.2)) { flashWhite = 0 }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.easeOut(duration: 1.0)) {
                destroyScale = 6.0
                destroyOpacity = 0
                destroyRotation = 18
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [self] in
            guard alive else { return }
            alive = false
            phase = .cleared
            onResult(.success)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 정리
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func invalidateAll() {
        roundTimer?.invalidate()
        spawnTimer?.invalidate()
        shakeTimer?.invalidate()
        heartTimer?.invalidate()
        moveTimer?.invalidate()
        scareShakeTimer?.invalidate()
    }

    private func cleanup() {
        alive = false
        invalidateAll()
    }
}
