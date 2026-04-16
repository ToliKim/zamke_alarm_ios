//
//  HwadeuljjakView.swift
//  ZAMKE
//
//  화들짝 모드 메인 뷰
//  Image("02") 변형 배경 + 사운드 + 미션 통합
//

import SwiftUI

struct HwadeuljjakView: View {

    var onBack: (() -> Void)? = nil

    @StateObject private var audioEngine = ZamkeAudioEngine()
    @StateObject private var missionManager = MissionManager()

    @State private var showMission = false
    @State private var missionCountdown = 3
    @State private var countdownActive = false
    @State private var flashRed = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var eyeOpacity: Double = 0.3
    @State private var threatText: String = "추적 중"
    @State private var threatDanger: Bool = false    // true = 붉은색
    @State private var threatBlink: Bool = false     // 위기 시 점멸
    @State private var elapsedSeconds: Int = 0       // 경과 시간
    @State private var statusTimer: Timer?
    @State private var threatSnapID: UUID = UUID()   // 텍스트 전환 시 snap
    @State private var dismissed = false
    @State private var systemStartTime = Date()

    // 축하 화면 애니메이션
    @State private var celebImgScale: CGFloat = 0.3   // 작게 시작
    @State private var celebImgOpacity: Double = 0     // 투명에서 시작
    @State private var celebImgBlur: CGFloat = 12      // 블러에서 시작
    @State private var celebTextOpacity: Double = 0
    @State private var celebSubTextOpacity: Double = 0
    @State private var celebMessageOpacity: Double = 0
    @State private var celebButtonOpacity: Double = 0
    @State private var celebGlow: Double = 0

    // 배경 flicker
    @State private var flicker: Double = 0.0

    // intensity 기반 배경 반응 (0.0~1.0) — audioEngine에서 직접
    private var intensity: Double {
        audioEngine.overallIntensity
    }

    var body: some View {
        ZStack {
            // ── 1) 변형된 배경 이미지 ──
            backgroundLayer

            // ── 2) 중앙 눈 강조 비네팅 ──
            vignetteLayer

            // ── 3) 단계별 어둡기 오버레이 ──
            Color.black.opacity(0.45 + intensity * 0.25)
                .ignoresSafeArea()

            // ── 4) 실패 플래시 ──
            Color.red.opacity(flashRed ? 0.35 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.12), value: flashRed)

            // ── 5) UI ──
            if dismissed {
                clearedView
            } else {
                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 16)

                    Spacer()

                    if countdownActive {
                        countdownView
                    } else if showMission {
                        missionContainerView
                    } else {
                        eyeView
                    }

                    Spacer()

                    footerView
                        .padding(.bottom, 30)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            startSystem()
            startFlicker()
        }
        .onDisappear { stopSystem() }
    }

    // MARK: - Background (변형된 Image 02)

    private var backgroundLayer: some View {
        GeometryReader { geo in
            ZStack {
                // 검정 배경 (scaledToFit 여백)
                Color.black

                Image("02")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    // 홈보다 어둡지만 형태 인식 가능
                    .opacity(0.60 - intensity * 0.15)
                    // 대비 상승 — 긴장감 + 윤곽 분리
                    .contrast(1.38 + intensity * 0.4)
                    // 미세 blur
                    .blur(radius: 2.5 + intensity * 1.5)
                    // 중간톤 + flicker
                    .brightness(0.035 + flicker * 0.04 - 0.02 + intensity * 0.02)

                // 상단 조명 — 갓 챙에 달빛
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.07), location: 0.0),
                        .init(color: Color.white.opacity(0.04), location: 0.12),
                        .init(color: Color.white.opacity(0.01), location: 0.25),
                        .init(color: Color.clear, location: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)

                // 얼굴 중간톤 — 안개 느낌
                RadialGradient(
                    colors: [
                        Color(white: 0.15, opacity: 0.18),
                        Color(white: 0.10, opacity: 0.08),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.32),
                    startRadius: geo.size.width * 0.05,
                    endRadius: geo.size.width * 0.40
                )
                .blendMode(.screen)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Vignette (중앙 눈 강조)

    private var vignetteLayer: some View {
        GeometryReader { geo in
            // 중앙은 약간 밝고, 가장자리는 어둡게
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7)
                ],
                center: .center,
                startRadius: geo.size.width * (0.15 - intensity * 0.05),
                endRadius: geo.size.width * 0.7
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Flicker Animation

    private func startFlicker() {
        withAnimation(
            .easeInOut(duration: Double.random(in: 2.5...4.0))
            .repeatForever(autoreverses: true)
        ) {
            flicker = 1.0
        }
    }

    // MARK: - Header (위협 인지 UI)

    private var headerView: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // ── 왼쪽: 위협 상태 텍스트 ──
                Text(threatText)
                    .id(threatSnapID)
                    .font(Font.system(size: 22, weight: .black).width(.condensed))
                    .tracking(1)
                    .foregroundColor(threatDanger
                        ? Color(red: 1.0, green: 0.23, blue: 0.23)
                        : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .opacity(threatBlink ? 0.3 : 1.0)
                    .shadow(color: threatDanger
                        ? Color.red.opacity(0.4) : .clear,
                        radius: threatDanger ? 8 : 0)
                    .transition(.identity)  // 즉각 전환, 부드러운 전환 없음

                Spacer()

                // ── 오른쪽: 경과 시간 ──
                Text("\(elapsedSeconds)초")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(elapsedSeconds > 30
                        ? Color(red: 1.0, green: 0.23, blue: 0.23)
                        : Color.white.opacity(0.6))
            }
            .padding(.horizontal, 24)

            // 위협 바 — intensity 기반
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 3)
                    Rectangle()
                        .fill(intensity > 0.6
                            ? Color(red: 1.0, green: 0.23, blue: 0.23)
                            : Color.white.opacity(0.3))
                        .frame(width: geo.size.width * intensity, height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Eye (존재 표시)

    private var eyeView: some View {
        ZStack {
            // 외부 링 (맥동)
            Circle()
                .stroke(Color.red.opacity(0.15 + intensity * 0.1), lineWidth: 1)
                .frame(width: 180, height: 180)
                .scaleEffect(pulseScale)

            // 눈 형태
            Ellipse()
                .fill(Color.red.opacity(eyeOpacity))
                .frame(width: 80, height: 40)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(eyeOpacity * 0.8))
                        .frame(width: 12, height: 12)
                )
                // 단계가 높을수록 눈 glow 강화
                .shadow(color: .red.opacity(intensity * 0.4), radius: 20 + intensity * 15)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        ZStack {
            // 잔상 효과
            Text("\(missionCountdown)")
                .font(.system(size: 120, weight: .ultraLight, design: .serif))
                .foregroundColor(.red.opacity(0.08))
                .scaleEffect(1.5)
                .blur(radius: 8)

            Text("\(missionCountdown)")
                .font(.system(size: 100, weight: .ultraLight, design: .serif))
                .tracking(6)
                .foregroundColor(.red.opacity(0.6))
                .shadow(color: .red.opacity(0.3), radius: 20)
        }
    }

    // MARK: - Cleared View

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 축하 화면 (03 이미지 + 줌인아웃 + 문구)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private let celebMessages = [
        "오늘도 좋은 하루 되세요",
        "당신은 이미 충분합니다",
        "오늘 하루도 빛날 거예요",
        "새로운 하루가 당신을 기다립니다",
        "할 수 있다는 걸 증명했습니다",
        "당신의 하루가 눈부시길",
        "오늘도 멋진 하루 시작하세요",
        "세상이 당신을 응원합니다",
    ]

    private var clearedView: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // ── 03 이미지 (작게→크게 생동감 등장 → 브리딩) ──
                Image("03")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(celebImgScale)
                    .opacity(celebImgOpacity)
                    .blur(radius: celebImgBlur)
                    .clipped()
                    .ignoresSafeArea()

                // ── 부드러운 비네트 ──
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.25),
                        Color.black.opacity(0.65)
                    ],
                    center: .center,
                    startRadius: geo.size.width * 0.22,
                    endRadius: geo.size.width * 0.75
                )
                .ignoresSafeArea()

                // ── 골든 글로우 ──
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.4).opacity(celebGlow * 0.18),
                        Color(red: 1.0, green: 0.75, blue: 0.3).opacity(celebGlow * 0.06),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 10,
                    endRadius: geo.size.width * 0.55
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // ── 콘텐츠 ──
                VStack(spacing: 0) {
                    Spacer()

                    // 축하 메인 텍스트 — 크고 밝게
                    Text("축 하 합 니 다")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .tracking(16)
                        .foregroundColor(.white)
                        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.7), radius: 30)
                        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.4), radius: 60)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        .opacity(celebTextOpacity)

                    Spacer().frame(height: 20)

                    // 구분선 — 더 밝게
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color(red: 1.0, green: 0.85, blue: 0.5).opacity(0.5),
                                    Color(red: 1.0, green: 0.85, blue: 0.5).opacity(0.6),
                                    Color(red: 1.0, green: 0.85, blue: 0.5).opacity(0.5),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 1)
                        .opacity(celebTextOpacity)

                    Spacer().frame(height: 24)

                    // 서브 텍스트 — 밝기 향상
                    Text("— 모든 미션을 완료했습니다 —")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .tracking(5)
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                        .opacity(celebSubTextOpacity)

                    Spacer().frame(height: 40)

                    // 랜덤 응원 메시지 — 크고 밝게
                    Text(celebMessages.randomElement() ?? "오늘도 좋은 하루 되세요")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .tracking(4)
                        .foregroundColor(Color(red: 1.0, green: 0.95, blue: 0.82))
                        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.5), radius: 20)
                        .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .opacity(celebMessageOpacity)

                    if missionManager.failCount > 0 {
                        Spacer().frame(height: 20)
                        Text("실패  \(missionManager.failCount)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(.white.opacity(0.35))
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .opacity(celebSubTextOpacity)
                    }

                    Spacer()

                    // 확인 버튼 — 더 선명하게
                    Button(action: {
                        stopSystem()
                        if let onBack = onBack {
                            onBack()
                        }
                    }) {
                        Text("확  인")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .tracking(10)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.2), radius: 15)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                    .opacity(celebButtonOpacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startCelebration() }
    }

    private func startCelebration() {
        // ━━ 1단계: 03 이미지 작게→크게 드라마틱 등장 (0→2초) ━━
        // 초기값: scale=0.3, opacity=0, blur=12
        withAnimation(.spring(response: 1.8, dampingFraction: 0.7, blendDuration: 0.5)) {
            celebImgScale = 1.05
            celebImgOpacity = 0.7
            celebImgBlur = 1.5
        }

        // ━━ 2단계: 등장 완료 후 브리딩 시작 (2초 후) ━━
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [self] in
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                celebImgScale = 1.15
            }
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                celebImgBlur = 0.5
            }
        }

        // 골든 글로우 맥동
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.5)) {
            celebGlow = 1.0
        }

        // 순차적 텍스트 등장 (이미지 등장 후에 나타남)
        withAnimation(.easeOut(duration: 1.2).delay(1.2)) {
            celebTextOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.0).delay(2.0)) {
            celebSubTextOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.2).delay(2.8)) {
            celebMessageOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(3.5)) {
            celebButtonOpacity = 1.0
        }
    }

    // MARK: - Mission Container

    private var missionContainerView: some View {
        Group {
            switch missionManager.currentMission {
            case .reaperGaze:
                ReaperGazeMissionView(
                    difficulty: missionManager.difficulty,
                    onResult: handleMissionResult,
                    audioEngine: audioEngine
                )
            case .redLight:
                RedLightMissionView(
                    difficulty: missionManager.difficulty,
                    onResult: handleMissionResult,
                    audioEngine: audioEngine
                )
            case .sentence:
                SentenceMissionView(
                    difficulty: missionManager.difficulty,
                    onResult: handleMissionResult,
                    audioEngine: audioEngine
                )
            case .breath:
                BreathMissionView(
                    difficulty: missionManager.difficulty,
                    onResult: handleMissionResult,
                    audioEngine: audioEngine
                )
            case .wisp:
                WispMissionView(
                    difficulty: missionManager.difficulty,
                    onResult: handleMissionResult,
                    audioEngine: audioEngine
                )
            }
        }
        .id(missionManager.missionAttemptID)
        .transition(.opacity)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            if showMission {
                // 미션 지시
                Text(missionManager.currentMission.instruction)
                    .font(Font.system(size: 20, weight: .heavy).width(.condensed))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96))

                Text("단계  \(missionManager.currentMission.rawValue + 1) / \(MissionType.totalCount)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.23))
            } else {
                Text("대  기")
                    .font(.system(size: 11, weight: .thin, design: .serif))
                    .tracking(10)
                    .foregroundColor(.white.opacity(0.15))
            }

            if missionManager.failCount > 0 {
                Text("실패 :  \(missionManager.failCount)")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.red.opacity(0.45))
            }
        }
    }

    // MARK: - System Start/Stop

    private func startSystem() {
        systemStartTime = Date()
        audioEngine.start()
        startStatusUpdater()
        startPulse()

        // 화들짝 시작 → z1 사운드 즉시 재생
        audioEngine.playZamkeStart()

        // z1 재생 후 3초 뒤부터 z 사운드 드문드문 루프 시작 (미션 전 대기 중)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
            audioEngine.startZamkeFailLoop()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 8...15)) { [self] in
            beginMissionCountdown()
        }
    }

    private func stopSystem() {
        audioEngine.stop()
        statusTimer?.invalidate()
    }

    private func startStatusUpdater() {
        let st = Timer(timeInterval: 0.5, repeats: true) { [self] _ in
            let phase = audioEngine.currentPhase
            let newText = phase.displayName
            let newDanger = phase.isDanger

            // 텍스트 변경 시 즉각 snap (부드러운 전환 없음)
            if newText != threatText {
                threatText = newText
                threatSnapID = UUID()  // 뷰 재생성 → 즉각 전환
                // 위험 단계 변경 시 햅틱
                if newDanger {
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.impactOccurred()
                }
            }

            threatDanger = newDanger
            eyeOpacity = 0.2 + audioEngine.overallIntensity * 0.6
            elapsedSeconds = Int(Date().timeIntervalSince(systemStartTime))

            // 위기 시 점멸 (pressure, domination)
            if phase.isDanger {
                threatBlink.toggle()
            } else {
                threatBlink = false
            }
        }
        RunLoop.main.add(st, forMode: .common)
        statusTimer = st
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }

    // MARK: - Mission Flow

    private func beginMissionCountdown() {
        countdownActive = true
        missionCountdown = 3
        audioEngine.escalate()

        let ct = Timer(timeInterval: 1, repeats: true) { [self] t in
            missionCountdown -= 1
            if missionCountdown <= 0 {
                t.invalidate()
                countdownActive = false
                showMission = true
                // 미션 시작 → Zamke 사운드 정지 (미션 중에는 조용히)
                audioEngine.stopZamke()
                missionManager.startMission()
            }
        }
        RunLoop.main.add(ct, forMode: .common)
    }

    private func handleMissionResult(_ result: MissionResult) {
        switch result {
        case .success:
            missionManager.reportResult(.success)
            if missionManager.isCompleted {
                audioEngine.stopZamke()
                dismissAlarm()
            } else {
                // 전환 대기 중 잠깐 z 사운드 → 1초 후 새 미션 시작 시 정지
                audioEngine.startZamkeFailLoop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { [self] in
                    audioEngine.stopZamke()
                }
            }

        case .failure:
            missionManager.reportResult(.failure)

            flashRed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in flashRed = false }

            audioEngine.playZamkeOnce()
            audioEngine.escalate()

            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
        }
    }

    private func dismissAlarm() {
        showMission = false
        audioEngine.stop()

        // ── 기록 저장 ──
        let duration = Date().timeIntervalSince(systemStartTime)
        HwadeuljjakRecordStore.shared.add(
            duration: duration,
            success: true,
            failCount: missionManager.failCount
        )

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.5)) {
            dismissed = true
        }
    }

    private func resetSystem() {
        dismissed = false
        showMission = false
        countdownActive = false
        missionCountdown = 3
        startSystem()
    }
}

#Preview {
    HwadeuljjakView()
        .preferredColorScheme(.dark)
}
