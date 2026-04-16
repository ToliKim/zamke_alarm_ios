//
//  RedLightMissionView.swift
//  ZAMKE
//
//  미션 2: 주시 — "눈 마주치면 죽는다"
//
//  ── 핵심 메카닉 ──
//  저승사자가 눈을 뜨고 너를 본다.
//  눈 뜬 동안 → 절대 움직이지 마. 심장 박동 햅틱. 화면 맥동.
//  눈 감은 동안 → 미친 듯이 연타해서 탈출 게이지를 채워라.
//  게이지 다 차면 라운드 클리어.
//
//  ── 공포 장치 ──
//  1. 라운드마다 저승사자가 점점 가까이 (줌 에스컬레이션)
//  2. 페이크 아웃: 가끔 눈이 감기는 척하다 번쩍 다시 뜸
//  3. 빨간 비네트 맥동 (심장 박동과 동기)
//  4. 텍스트 공포 에스컬레이션
//  5. 불규칙 타이밍 — 예측 불가
//
//  ── 5라운드 ──
//  라운드↑ → 눈 감는 시간↓, 필요 탭 수↑, 저승사자 더 가까이
//  실패 → 점프스케어 + 1라운드 되돌리기
//  올 클리어 → 저승사자 파괴
//
//  ⚠️ 안정성:
//  - .task {} 사용 (.onAppear 대신)
//  - gameStarted 플래그
//  - onDisappear cleanup
//  - Timer 기반 (asyncAfter 체인 최소화)
//

import SwiftUI

struct RedLightMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 페이즈 ──
    enum Phase {
        case darkness       // 암전
        case eyeOpen        // 눈 뜸 — 절대 터치 금지
        case eyeClosing     // 페이크: 감기는 척 (0.3초) → 다시 open
        case eyeClosed      // 진짜 감음 — 연타 기회
        case jumpScare      // 터치 실패
        case destroying     // 올 클리어 파괴 연출
        case cleared        // 성공
    }

    @State private var phase: Phase = .darkness
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 5

    // ── 연타 게이지 ──
    @State private var tapCount = 0
    @State private var gaugeProgress: CGFloat = 0   // 0.0 ~ 1.0

    // 라운드별 필요 탭 수
    private func requiredTaps(_ r: Int) -> Int {
        switch r {
        case 0: return 5
        case 1: return 7
        case 2: return 10
        case 3: return 13
        default: return 15
        }
    }

    // ── 02.png 비주얼 ──
    @State private var imgScale: CGFloat = 1.0
    @State private var imgBlur: CGFloat = 10
    @State private var imgOpacity: Double = 0
    @State private var redGlow: Double = 0
    @State private var shakeX: CGFloat = 0
    @State private var shakeY: CGFloat = 0

    // ── 비네트 맥동 ──
    @State private var vignetteOpacity: Double = 0
    @State private var heartbeatPhase: Bool = false   // 맥동 토글

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

    // ── 텍스트 ──
    @State private var displayText: String = ""
    @State private var textColor: Color = .red
    @State private var textOpacity: Double = 0

    // ── 타이머 ──
    @State private var eyeTimer: Timer?       // 눈 뜨기/감기 전환
    @State private var roundTimer: Timer?     // 라운드 제한시간
    @State private var shakeTimer: Timer?     // 미세 떨림
    @State private var heartTimer: Timer?     // 심장 박동
    @State private var gaugeDecayTimer: Timer?  // 게이지 감소 (안 누르면 줄어듦)

    // ── 화면 ──
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var gameStarted = false

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드별 파라미터
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // 저승사자 줌 레벨 (라운드마다 더 가까이)
    private func reaperScale(_ r: Int) -> CGFloat {
        switch r {
        case 0: return 1.15
        case 1: return 1.28
        case 2: return 1.42
        case 3: return 1.58
        default: return 1.75
        }
    }

    // 눈 뜨고 있는 시간 (유저가 참아야 하는 시간) — 느긋하게
    private func eyeOpenRange(_ r: Int) -> ClosedRange<Double> {
        switch r {
        case 0: return 3.5...6.0
        case 1: return 3.0...5.5
        case 2: return 2.5...5.0
        case 3: return 2.0...4.5
        default: return 1.8...4.0
        }
    }

    // 눈 감는 시간 (연타 기회) — 30% 더 넉넉하게
    private func eyeClosedRange(_ r: Int) -> ClosedRange<Double> {
        switch r {
        case 0: return 4.5...6.5
        case 1: return 4.0...6.0
        case 2: return 3.2...5.2
        case 3: return 2.6...4.5
        default: return 2.0...3.2
        }
    }

    // 라운드 제한시간 — 30% 더 여유
    private func timeLimitForRound(_ r: Int) -> Double {
        switch r {
        case 0: return 58.0
        case 1: return 52.0
        case 2: return 45.0
        case 3: return 36.0
        default: return 28.0
        }
    }

    // 심장 박동 간격 (라운드마다 빨라짐) — 조금 느리게 시작
    private func heartbeatInterval(_ r: Int) -> Double {
        switch r {
        case 0: return 1.0
        case 1: return 0.85
        case 2: return 0.65
        case 3: return 0.5
        default: return 0.38
        }
    }

    // 페이크 아웃 확률 — 30% 감소
    private func fakeOutChance(_ r: Int) -> Double {
        switch r {
        case 0: return 0.0       // 1라운드: 페이크 없음
        case 1: return 0.0       // 2라운드도 페이크 없음
        case 2: return 0.15
        case 3: return 0.25
        default: return 0.35
        }
    }

    // 공포 텍스트 (라운드별 에스컬레이션)
    private func scareText(_ r: Int) -> String {
        switch r {
        case 0: return "조용히…"
        case 1: return "움직이지 마"
        case 2: return "보고 있다"
        case 3: return "너를 찾았다"
        default: return "끝이다"
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // ── 02.png: 저승사자 ──
                if phase == .eyeOpen || phase == .eyeClosing || phase == .eyeClosed {
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
                            green: max(0.08, 1.0 - redGlow * 0.92),
                            blue: max(0.03, 1.0 - redGlow * 0.97)
                        ))
                        .clipped()
                        .onTapGesture { handleTap() }
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

                // ── 점프스케어 (격렬한 흔들림) ──
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

                    // ── 상단: 라운드 인디케이터 ──
                    HStack(spacing: 8) {
                        ForEach(0..<totalRounds, id: \.self) { i in
                            Circle()
                                .fill(i < round
                                      ? Color.green.opacity(0.8)
                                      : (i == round
                                         ? Color(red: 1.0, green: 0.15, blue: 0.1)
                                         : Color.white.opacity(0.08)))
                                .frame(width: 10, height: 10)
                                .shadow(color: i == round
                                        ? Color.red.opacity(0.6) : .clear,
                                        radius: 6)
                        }
                    }
                    .padding(.top, 16)

                    Spacer()

                    // ── 중앙: 연타 게이지 (눈 감은 상태에서만) ──
                    if phase == .eyeClosed {
                        VStack(spacing: 12) {
                            // 게이지 바
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.0, green: 0.8, blue: 0.3),
                                                Color(red: 0.0, green: 1.0, blue: 0.5)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, (screenW - 80) * gaugeProgress), height: 8)
                                    .shadow(color: .green.opacity(0.6), radius: 8)
                            }
                            .frame(width: screenW - 80)

                            Text("연타!")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.green.opacity(0.9))
                                .shadow(color: .green.opacity(0.5), radius: 10)
                        }
                    }

                    Spacer()

                    // ── 하단: 상태 텍스트 ──
                    Group {
                        if phase == .darkness {
                            Text("…")
                                .foregroundColor(.white.opacity(0.08))
                        } else if phase == .eyeOpen || phase == .eyeClosing {
                            Text(displayText)
                                .foregroundColor(Color(red: 1.0, green: 0.08, blue: 0.04))
                                .shadow(color: .red.opacity(0.8), radius: 30)
                                .opacity(textOpacity)
                        } else if phase == .eyeClosed {
                            Text("지금!")
                                .foregroundColor(.green.opacity(0.95))
                                .shadow(color: .green.opacity(0.6), radius: 20)
                        } else if phase == .destroying {
                            Text("소멸")
                                .foregroundColor(.green.opacity(0.7))
                                .shadow(color: .green.opacity(0.4), radius: 15)
                        }
                    }
                    .font(Font.system(size: 38, weight: .black).width(.condensed))

                    Spacer().frame(height: 40)
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
    // MARK: - 게임 시작
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startGame() {
        alive = true
        round = 0
        startRound()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 시작
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startRound() {
        guard alive, round < totalRounds else { return }
        invalidateAll()
        phase = .darkness
        tapCount = 0
        gaugeProgress = 0
        imgOpacity = 0
        imgScale = 1.0
        imgBlur = 10
        redGlow = 0
        shakeX = 0
        shakeY = 0
        vignetteOpacity = 0
        screenFlashRed = 0
        scareOpacity = 0
        flashWhite = 0
        displayText = ""
        textOpacity = 0

        // 암전 — 불규칙한 대기 (공포의 정적)
        let wait = Double.random(in: 1.5...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
            guard alive, phase == .darkness else { return }
            // 잠깨 목소리 — 눈 뜨기 직전 (매 라운드)
            audioEngine?.playZamkeOnce()
            openEyes()
            startRoundTimer()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startRoundTimer() {
        roundTimer?.invalidate()
        let limit = timeLimitForRound(round)
        let rt = Timer(timeInterval: limit, repeats: false) { [self] _ in
            guard alive else { return }
            if phase == .eyeOpen || phase == .eyeClosed || phase == .eyeClosing {
                roundFailed()
            }
        }
        RunLoop.main.add(rt, forMode: .common)
        roundTimer = rt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 뜨기 (위험 — 절대 터치 금지)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func openEyes() {
        guard alive else { return }
        phase = .eyeOpen

        let targetScale = reaperScale(round)
        displayText = scareText(round)

        // ━━ 순간적으로 선명하게 — 공포의 순간 ━━
        withAnimation(.easeIn(duration: 0.04)) {
            imgOpacity = 0.95
            imgBlur = 0
            imgScale = targetScale
            redGlow = 0.75
            textOpacity = 1.0
        }

        // 비네트 맥동 시작
        withAnimation(.easeIn(duration: 0.15)) {
            vignetteOpacity = 0.7
        }

        // 찰칵 — 공포의 눈 뜨는 소리

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }

        // 미세 떨림 시작 (이미지 + Y축 추가)
        startShake()

        // 심장 박동 시작
        startHeartbeat()

        // ── 불규칙 시간 후 → 페이크 or 진짜 눈 감기 ──
        let duration = Double.random(in: eyeOpenRange(round))
        eyeTimer?.invalidate()
        let et = Timer(timeInterval: duration, repeats: false) { [self] _ in
            guard alive, phase == .eyeOpen else { return }

            // 페이크 아웃 판정
            if Double.random(in: 0...1) < fakeOutChance(round) {
                fakeClose()
            } else {
                closeEyes()
            }
        }
        RunLoop.main.add(et, forMode: .common)
        eyeTimer = et
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 페이크 아웃 (감기는 척 → 번쩍)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func fakeClose() {
        guard alive else { return }
        phase = .eyeClosing

        // 잠깐 어두워지는 척
        withAnimation(.easeOut(duration: 0.2)) {
            imgOpacity = 0.35
            imgBlur = 4
            redGlow = 0.2
            vignetteOpacity = 0.2
        }

        // 0.25~0.4초 후 번쩍 다시 뜸
        let fakeDelay = Double.random(in: 0.25...0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + fakeDelay) { [self] in
            guard alive, phase == .eyeClosing else { return }
            phase = .eyeOpen

            // 더 강렬하게 번쩍
            withAnimation(.easeIn(duration: 0.03)) {
                imgOpacity = 1.0
                imgBlur = 0
                redGlow = 0.9
                vignetteOpacity = 0.85
            }

            // 강한 햅틱 — "속았지?"
    
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }

            // 다시 정상 눈뜬 상태로 복귀
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                guard alive, phase == .eyeOpen else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    imgOpacity = 0.95
                    redGlow = 0.75
                    vignetteOpacity = 0.7
                }
            }

            // 다시 타이머 설정 (이번엔 진짜 감기)
            let duration = Double.random(in: eyeOpenRange(round))
            eyeTimer?.invalidate()
            let et = Timer(timeInterval: duration, repeats: false) { [self] _ in
                guard alive, phase == .eyeOpen else { return }
                closeEyes()
            }
            RunLoop.main.add(et, forMode: .common)
            eyeTimer = et
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 감기 (안전 — 연타 기회)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func closeEyes() {
        guard alive else { return }
        phase = .eyeClosed

        // 심장 박동 + 떨림 정지
        heartTimer?.invalidate()
        shakeTimer?.invalidate()

        // ━━ 어두워짐 — 짧은 기회 ━━
        withAnimation(.easeOut(duration: 0.2)) {
            imgOpacity = 0.12
            imgBlur = 12
            imgScale = 1.0
            redGlow = 0
            shakeX = 0
            shakeY = 0
            vignetteOpacity = 0
            textOpacity = 0
        }

        // 게이지 감소 타이머 시작 (안 누르면 천천히 줄어듦)
        startGaugeDecay()

        // 불규칙 시간 후 다시 눈 뜨기
        let duration = Double.random(in: eyeClosedRange(round))
        eyeTimer?.invalidate()
        let et = Timer(timeInterval: duration, repeats: false) { [self] _ in
            guard alive, phase == .eyeClosed else { return }
            gaugeDecayTimer?.invalidate()
            openEyes()
        }
        RunLoop.main.add(et, forMode: .common)
        eyeTimer = et
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심장 박동 (눈 뜬 동안)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startHeartbeat() {
        heartTimer?.invalidate()
        let interval = heartbeatInterval(round)

        let ht = Timer(timeInterval: interval, repeats: true) { [self] _ in
            guard alive, phase == .eyeOpen else {
                heartTimer?.invalidate()
                return
            }

            heartbeatPhase.toggle()

            // 햅틱: 쿵…쿵…
            if heartbeatPhase {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            // 비네트 맥동
            withAnimation(.easeInOut(duration: interval * 0.4)) {
                vignetteOpacity = heartbeatPhase ? 0.85 : 0.55
                redGlow = heartbeatPhase ? 0.85 : 0.6
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
        let intensity: CGFloat = 1.0 + CGFloat(round) * 0.5
        let st = Timer(timeInterval: 0.06, repeats: true) { [self] _ in
            guard alive, phase == .eyeOpen || phase == .eyeClosing else {
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
    // MARK: - 게이지 감소 (안 누르면 줄어듦)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startGaugeDecay() {
        gaugeDecayTimer?.invalidate()
        let gdt = Timer(timeInterval: 0.15, repeats: true) { [self] _ in
            guard alive, phase == .eyeClosed else {
                gaugeDecayTimer?.invalidate()
                return
            }
            if gaugeProgress > 0 {
                gaugeProgress = max(0, gaugeProgress - 0.005)
            }
        }
        RunLoop.main.add(gdt, forMode: .common)
        gaugeDecayTimer = gdt
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 터치 핸들러
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func handleTap() {
        guard alive else { return }

        switch phase {
        case .eyeOpen, .eyeClosing:
            // ☠️ 눈 마주침 — 즉사
            roundFailed()

        case .eyeClosed:
            // ✅ 연타!
            tapCount += 1
            let required = requiredTaps(round)
            gaugeProgress = min(1.0, CGFloat(tapCount) / CGFloat(required))

            // 연타 햅틱 (가벼운 탭 느낌)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // 터치 피드백: 잠깐 밝아짐
            withAnimation(.easeOut(duration: 0.05)) {
                imgOpacity = 0.25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [self] in
                guard alive, phase == .eyeClosed else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    imgOpacity = 0.12
                }
            }

            if tapCount >= required {
                roundCleared()
            }

        default:
            break
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 클리어
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundCleared() {
        invalidateAll()

        // 게이지 만충 → 초록 플래시
        withAnimation(.easeOut(duration: 0.15)) {
            gaugeProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            guard alive else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                imgOpacity = 0
                imgBlur = 15
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        round += 1

        if round >= totalRounds {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                guard alive else { return }
                destroyReaper()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard alive else { return }
                startRound()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 실패 → 점프스케어
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundFailed() {
        guard alive else { return }
        phase = .jumpScare
        invalidateAll()

        // ━━ 즉시 점프스케어 (딜레이 0) ━━
        scareScale = 1.8
        scareOpacity = 1.0
        screenFlashRed = 0.7
        imgOpacity = 0
        vignetteOpacity = 0

        // ━━ 음향 폭풍 4파 + 잠깨 목소리 ━━

        // 1차: 즉시
        audioEngine?.fireFailureBlast()
        audioEngine?.playZamkeOnce()

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 2차: 0.3초 후
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
    
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 3차: 0.6초 후
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 4차: 0.95초 후
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 줌인 강화 + 회전 충격
        withAnimation(.easeIn(duration: 0.2)) {
            scareScale = 2.5
            screenFlashRed = 0.85
        }

        // ━━ 저승사자 격렬한 흔들림 ━━
        scareShakeTimer?.invalidate()
        let sst = Timer(timeInterval: 0.04, repeats: true) { [self] _ in
            guard alive || phase == .jumpScare else {
                scareShakeTimer?.invalidate()
                return
            }
            scareShakeX = CGFloat.random(in: -18...18)
            scareShakeY = CGFloat.random(in: -12...12)
        }
        RunLoop.main.add(sst, forMode: .common)
        scareShakeTimer = sst

        // 한 라운드 되돌리기
        round = max(0, round - 1)

        // 2.5초 후 페이드 → 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            guard alive else { return }
            scareShakeTimer?.invalidate()
            scareShakeX = 0
            scareShakeY = 0
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
    // MARK: - 저승사자 파괴 (5라운드 올 클리어)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func destroyReaper() {
        guard alive else { return }
        phase = .destroying

        destroyScale = 1.3
        destroyOpacity = 1.0
        destroyRotation = 0
        flashWhite = 0

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // 1단계: 흰 플래시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            guard alive else { return }
    
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.easeIn(duration: 0.1)) {
                flashWhite = 0.95
            }
        }

        // 2단계: 확대 소멸 + 회전
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
            guard alive else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                flashWhite = 0
            }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.easeOut(duration: 1.0)) {
                destroyScale = 6.0
                destroyOpacity = 0
                destroyRotation = 18
            }
        }

        // 3단계: 성공
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
        eyeTimer?.invalidate()
        roundTimer?.invalidate()
        shakeTimer?.invalidate()
        heartTimer?.invalidate()
        gaugeDecayTimer?.invalidate()
        scareShakeTimer?.invalidate()
    }

    private func cleanup() {
        alive = false
        invalidateAll()
    }
}
