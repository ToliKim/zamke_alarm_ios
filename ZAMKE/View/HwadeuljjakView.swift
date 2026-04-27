//
//  HwadeuljjakView.swift
//  ZAMKE
//
//  화들짝 모드 메인 뷰
//  Image("02") 변형 배경 + 사운드 + 미션 통합
//

import SwiftUI
import AVFoundation

struct HwadeuljjakView: View {

    var onBack: (() -> Void)? = nil

    @StateObject private var audioEngine = ZamkeAudioEngine()
    @State private var missionManager = MissionManager()

    @State private var showMission = false
    @State private var missionCountdown = 3
    @State private var countdownActive = false
    @State private var flashRed = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var eyeOpacity: Double = 0.3
    @State private var phaseText: String = "침투"
    @State private var intensityPercent: Int = 0
    @State private var statusTimer: Timer?
    @State private var dismissed = false

    // 포기(루저) 연출
    @State private var showLoser = false
    @State private var loserReaperScale: CGFloat = 1.6
    @State private var loserReaperOpacity: Double = 0
    @State private var loserShakeX: CGFloat = 0
    @State private var loserShakeY: CGFloat = 0
    @State private var loserShakeTimer: Timer?
    @State private var loserTextOpacity: Double = 0

    // 시스템 시작 시간 (기록용)
    @State private var systemStartTime: Date = Date()

    // 배경 flicker
    @State private var flicker: Double = 0.0

    // 벨 소리 플레이어
    @State private var bellPlayer: AVAudioPlayer?

    // intensity 기반 배경 반응 (0.0~1.0)
    private var intensity: Double {
        Double(intensityPercent) / 100.0
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
            if showLoser {
                loserView
            } else if dismissed {
                clearedView
            } else {
                VStack(spacing: 0) {
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
                        .padding(.bottom, 10)

                    // ── 포기 버튼 (미션 진행 중에만) ──
                    if showMission && !missionManager.transitioning {
                        giveUpButton
                            .padding(.bottom, 30)
                    } else {
                        Spacer().frame(height: 30)
                    }
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            startSystem()
            startFlicker()
        }
        .onDisappear { stopSystem() }
        .onChange(of: missionManager.transitioning) { _, isTransitioning in
            if !isTransitioning && showMission {
                // 전환 끝 → 새 미션 시작 → z 사운드 정지
                audioEngine.stopZamke()
            }
        }
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

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom) {
                // 단계명 — 얇고 넓은 간격
                Text("「  \(phaseText)  」")
                    .font(.system(size: 14, weight: .thin, design: .serif))
                    .tracking(8)
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                // 퍼센트 — 극도로 가는 대형 숫자
                Text("\(intensityPercent)%")
                    .font(.system(size: 16, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.red.opacity(0.4 + Double(intensityPercent) / 150.0))
            }
            .padding(.horizontal, 24)

            // 강도 바 — 미세한 선
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 1)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(intensityPercent) / 100.0, height: 1)
                }
            }
            .frame(height: 1)
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

    @State private var clearedImgScale: CGFloat = 0.5
    @State private var clearedImgOpacity: Double = 0
    @State private var clearedTextOpacity: Double = 0
    @State private var clearedGlow: Double = 0

    private var clearedView: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.08)
                .ignoresSafeArea()

            // 03 이미지 — 귀여운 축하
            Image("03")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .scaleEffect(clearedImgScale)
                .opacity(clearedImgOpacity)
                .shadow(color: .green.opacity(clearedGlow * 0.3), radius: 25)

            // 부드러운 녹색 glow
            RadialGradient(
                colors: [
                    Color.green.opacity(clearedGlow * 0.08),
                    Color.green.opacity(clearedGlow * 0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 250
            )
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                Spacer()

                Text("탈 출  성 공")
                    .font(.system(size: 30, weight: .thin, design: .serif))
                    .tracking(12)
                    .foregroundColor(.green.opacity(0.8))
                    .shadow(color: .green.opacity(0.3), radius: 15)

                Text("— 모든 미션을 완료했습니다 —")
                    .font(.system(size: 11, weight: .light, design: .serif))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.4))

                if missionManager.failCount > 0 {
                    Text("실패  \(missionManager.failCount)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.25))
                }

                Spacer().frame(height: 30)

                Button(action: {
                    stopSystem()
                    if let onBack = onBack {
                        onBack()
                    }
                }) {
                    Text("확  인")
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .tracking(8)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.2), lineWidth: 0.8)
                        )
                }
                .padding(.bottom, 50)
            }
            .opacity(clearedTextOpacity)
        }
        .onAppear {
            playClearedAnimation()
        }
    }

    private func playClearedAnimation() {
        // 03 이미지 스프링 등장
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
            clearedImgScale = 1.0
            clearedImgOpacity = 1.0
        }

        withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
            clearedGlow = 1.0
        }

        withAnimation(.easeIn(duration: 0.6).delay(0.5)) {
            clearedTextOpacity = 1.0
        }

        // 부드러운 idle 맥동
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                clearedImgScale = 1.05
            }
        }

        // 랜덤 벨 소리 재생
        playRandomBell()
    }

    private func playRandomBell() {
        let bellSounds = ["b1", "b2", "b3", "b4", "b5", "b6"]
        guard let bellName = bellSounds.randomElement() else { return }

        // 번들에서 벨 파일 찾기
        let url: URL? = {
            if let u = Bundle.main.url(forResource: bellName, withExtension: "wav", subdirectory: "audio/Bell") { return u }
            if let u = Bundle.main.url(forResource: bellName, withExtension: "wav", subdirectory: "Bell") { return u }
            if let u = Bundle.main.url(forResource: bellName, withExtension: "wav") { return u }
            // 전체 탐색
            if let bp = Bundle.main.resourcePath,
               let en = FileManager.default.enumerator(atPath: bp) {
                while let p = en.nextObject() as? String {
                    if p.hasSuffix("/\(bellName).wav") || p == "\(bellName).wav" {
                        return URL(fileURLWithPath: bp).appendingPathComponent(p)
                    }
                }
            }
            return nil
        }()

        guard let fileURL = url else { return }
        do {
            bellPlayer = try AVAudioPlayer(contentsOf: fileURL)
            bellPlayer?.volume = 0.8
            bellPlayer?.numberOfLoops = 0
            bellPlayer?.play()
        } catch {
            #if DEBUG
            print("벨 재생 실패: \(error)")
            #endif
        }
    }

    // MARK: - Mission Container

    private var missionContainerView: some View {
        Group {
            if missionManager.transitioning {
                // 미션 전환 중 2초 대기 화면
                VStack(spacing: 16) {
                    Text("다 음  미 션  준 비")
                        .font(.system(size: 15, weight: .thin, design: .serif))
                        .tracking(6)
                        .foregroundColor(.white.opacity(0.4))

                    // 맥동하는 점
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 6, height: 6)
                                .opacity(transitionDotOpacity(index: i))
                        }
                    }
                }
            } else {
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
                }
            }
        }
        .id(missionManager.missionAttemptID)
        .transition(.opacity)
    }

    @State private var transitionDotPhase: Double = 0

    private func transitionDotOpacity(index: Int) -> Double {
        let phase = (Date.timeIntervalSinceReferenceDate * 2.0 + Double(index) * 0.5)
        return 0.3 + 0.7 * abs(sin(phase))
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 10) {
            if showMission {
                // 미션 지시
                Text(missionManager.currentMission.instruction)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.7))
                    .shadow(color: .white.opacity(0.1), radius: 6)

                // 단계
                Text("단계  \(missionManager.currentMission.rawValue + 1) / \(MissionType.totalCount)")
                    .font(.system(size: 13, weight: .light, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Text("대  기")
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .tracking(10)
                    .foregroundColor(.white.opacity(0.35))
            }

            if missionManager.failCount > 0 {
                Text("실패 :  \(missionManager.failCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.red.opacity(0.6))
            }
        }
    }

    // MARK: - Give Up Button

    private var giveUpButton: some View {
        Button(action: { giveUp() }) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("포기")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(4)
            }
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.08, blue: 0.08),
                                Color(red: 0.5, green: 0.04, blue: 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .red.opacity(0.3), radius: 10, y: 3)
        }
    }

    // MARK: - Loser View (포기 연출)

    private var loserView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 붉은 저승사자 — 흔들림
            Image("02")
                .resizable()
                .scaledToFit()
                .scaleEffect(loserReaperScale)
                .opacity(loserReaperOpacity)
                .offset(x: loserShakeX, y: loserShakeY)
                .colorMultiply(Color(red: 1.0, green: 0.05, blue: 0.02))
                .shadow(color: .red.opacity(0.5), radius: 30)

            // 붉은 비네트
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.red.opacity(0.15),
                    Color.red.opacity(0.35)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 20) {
                Spacer()

                // 루저 텍스트
                Text("나 는  루 저 다")
                    .font(.system(size: 32, weight: .black, design: .serif))
                    .tracking(8)
                    .foregroundColor(.red.opacity(0.9))
                    .shadow(color: .red.opacity(0.6), radius: 25)
                    .opacity(loserTextOpacity)

                Text("— 포기했습니다 —")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.3))
                    .opacity(loserTextOpacity)

                Spacer().frame(height: 60)

                // 확인 버튼
                Button(action: {
                    loserShakeTimer?.invalidate()
                    stopSystem()
                    onBack?()
                }) {
                    Text("확  인")
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .tracking(8)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .opacity(loserTextOpacity)
                .padding(.bottom, 50)
            }
        }
    }

    private func giveUp() {
        // 기록 저장 (루저)
        let duration = Date().timeIntervalSince(systemStartTime)
        HwadeuljjakRecordStore.shared.add(
            duration: duration,
            success: false,
            failCount: missionManager.failCount
        )

        // 사운드 + 햅틱
        audioEngine.fireAjaeng()
        audioEngine.playZamkeOnce()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // 루저 화면 전환
        showMission = false
        countdownActive = false

        withAnimation(.easeInOut(duration: 0.3)) {
            showLoser = true
        }

        // 저승사자 등장
        withAnimation(.easeIn(duration: 0.5)) {
            loserReaperOpacity = 0.85
            loserReaperScale = 1.2
        }

        // 텍스트 등장
        withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
            loserTextOpacity = 1.0
        }

        // 격렬한 흔들림
        loserShakeTimer?.invalidate()
        let st = Timer(timeInterval: 0.04, repeats: true) { _ in
            loserShakeX = CGFloat.random(in: -14...14)
            loserShakeY = CGFloat.random(in: -10...10)
        }
        RunLoop.main.add(st, forMode: .common)
        loserShakeTimer = st

        // 3초 후 흔들림 감소
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
            loserShakeTimer?.invalidate()
            withAnimation(.easeOut(duration: 0.3)) {
                loserShakeX = 0
                loserShakeY = 0
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

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 8...15)) {
            beginMissionCountdown()
        }
    }

    private func stopSystem() {
        audioEngine.stop()
        statusTimer?.invalidate()
        loserShakeTimer?.invalidate()
        bellPlayer?.stop()
        bellPlayer = nil
    }

    private func startStatusUpdater() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            phaseText = audioEngine.currentPhase.displayName
            intensityPercent = Int(audioEngine.overallIntensity * 100)
            eyeOpacity = 0.2 + audioEngine.overallIntensity * 0.6
        }
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

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            missionCountdown -= 1
            if missionCountdown <= 0 {
                t.invalidate()
                countdownActive = false
                showMission = true
                // 미션 시작 → Zamke 사운드 정지 (미션 중에는 조용히)
                audioEngine.stopZamke()
                missionManager.onMissionTransitionEnd = { [self] in
                    // 다음 미션 시작 직전 → zamke 루프 정지
                    audioEngine.stopZamke()
                }
                missionManager.startMission()
            }
        }
    }

    private func handleMissionResult(_ result: MissionResult) {
        switch result {
        case .success:
            missionManager.reportResult(.success)
            if missionManager.isCompleted {
                audioEngine.stopZamke()
                dismissAlarm()
            } else {
                // 미션 전환 대기 중 → z 사운드 드문드문 재생
                audioEngine.startZamkeFailLoop()
            }

        case .failure:
            missionManager.reportResult(.failure)

            flashRed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { flashRed = false }

            audioEngine.fireAjaeng()
            audioEngine.escalate()

            // 미션 실패 → z 사운드 한 번 재생 (미션 즉시 재시작이므로 루프 아닌 단발)
            audioEngine.playZamkeOnce()

            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
        }
    }

    private func dismissAlarm() {
        showMission = false
        audioEngine.stop()

        // 기록 저장 (성공)
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
