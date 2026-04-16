//
//  ContentView.swift
//  ZAMKE
//
//  메인 홈 — "살아있는 공포 인터페이스"
//
//  ── 핵심 경험 ──
//  버튼을 누르는 것이 아니라 "어떤 존재와 상호작용하고 있다"
//  심리적 압박 + 몰입 + 성취감
//
//  ── 버튼 UI ──
//  안개 속에서 떠오르는 존재, 글리치 텍스트, 미세 흔들림, 깜빡임
//
//  ── 인터랙션 ──
//  빨려 들어가는 터치 + 눈 반응 + 유휴 시 눈 변화
//

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - ContentView
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ContentView: View {

    @State private var selectedMode: AppMode? = nil

    // 배경 브리딩
    @State private var breathe: Double = 0.0

    // 타이틀 애니메이션
    @State private var titleScale: CGFloat = 0.88
    @State private var titleOpacity: Double = 0.0
    @State private var titleShake: CGFloat = 0.0
    @State private var titleBlur: CGFloat = 3.0

    // 버튼 등장 단계 (0: 없음, 1: 안개, 2: 형태, 3: 텍스트)
    @State private var entrancePhase: Int = 0

    // 눈 인터랙션
    @State private var eyeFlashBrightness: Double = 0   // 번쩍임
    @State private var eyeOffsetX: CGFloat = 0           // 좌우 이동
    @State private var eyeBlinkOpacity: Double = 1.0     // 깜빡임
    @State private var eyeIdleScale: CGFloat = 1.0       // 유휴 확대

    // 유휴 감지
    @State private var lastInteraction: Date = Date()
    @State private var idleTimer: Timer?

    // 선택 하이라이트
    @State private var highlightedMode: AppMode? = nil

    // 설정 시트
    @State private var showTerms = false
    @State private var showPrivacy = false

    // 푸른빛 흰색
    private let blueWhite = Color(red: 0.82, green: 0.86, blue: 0.96)

    var body: some View {
        ZStack {
            if let mode = selectedMode {
                modeView(for: mode)
                    .transition(.opacity)
            } else {
                homeView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: selectedMode)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Home
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var homeView: some View {
        GeometryReader { geo in
            ZStack {
                // ── 0) 완전한 블랙 배경 ──
                Color.black.ignoresSafeArea()

                // ── 1) 배경 이미지 (눈 인터랙션 적용) ──
                Image("02")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.90)
                    .contrast(1.25)
                    .brightness(0.02 + breathe * 0.012 + eyeFlashBrightness)
                    .scaleEffect(eyeIdleScale)
                    .offset(x: eyeOffsetX)
                    .opacity(eyeBlinkOpacity)
                    .ignoresSafeArea()

                // ── 2) 상단 조명 ──
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.08), location: 0.0),
                        .init(color: Color.white.opacity(0.04), location: 0.12),
                        .init(color: Color.white.opacity(0.01), location: 0.25),
                        .init(color: Color.clear, location: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)
                .ignoresSafeArea()

                // ── 3) 얼굴 중간톤 ──
                RadialGradient(
                    colors: [
                        Color(white: 0.15, opacity: 0.20),
                        Color(white: 0.10, opacity: 0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.32),
                    startRadius: geo.size.width * 0.05,
                    endRadius: geo.size.width * 0.42
                )
                .blendMode(.screen)
                .ignoresSafeArea()

                // ── 4) 하단 암전 그래디언트 ──
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * 0.58)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.75),
                            Color.black.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()

                // ── ZAMKE 타이틀 ──
                zamkeTitleView
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.22)

                // ── 5) 버튼 영역 ──
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()

                    VStack(spacing: 14) {
                        ForEach(Array(AppMode.allCases.enumerated()), id: \.element.id) { index, mode in
                            fogButton(mode: mode, index: index)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                        .frame(height: geo.size.height * 0.11)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startBreathe()
            startTitleAnimations()
            startIdleTimer()
            startEntrance()
        }
        .onDisappear {
            idleTimer?.invalidate()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 안개 버튼 (Fog Button)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func fogButton(mode: AppMode, index: Int) -> some View {
        let isHighlighted = highlightedMode == mode
        let delay = Double(index) * 0.15

        return Button {
            buttonTapped(mode)
        } label: {
            ZStack {
                // ── 안개 레이어 ──
                if entrancePhase >= 1 {
                    FogLayer(seed: index)
                        .opacity(entrancePhase >= 1 ? 1.0 : 0.0)
                }

                // ── 버튼 배경 ──
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isHighlighted
                                ? Color.red.opacity(0.25)
                                : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                    .opacity(entrancePhase >= 2 ? 1.0 : 0.0)

                // ── 선택 상태: 붉은 기운 + 맥박 ──
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.red.opacity(0.12),
                                    Color.red.opacity(0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 120
                            )
                        )
                }

                // ── 콘텐츠 ──
                HStack(spacing: 14) {
                    Image(systemName: mode.sfSymbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(
                            isHighlighted
                            ? Color.red.opacity(0.7)
                            : blueWhite.opacity(0.4)
                        )
                        .frame(width: 24)

                    if entrancePhase >= 3 {
                        GlitchText(
                            text: mode.title,
                            isHighlighted: isHighlighted
                        )
                    }

                    Spacer()
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 56)
            // soft glow + 그림자 (떠 있는 느낌)
            .shadow(
                color: isHighlighted
                    ? Color.red.opacity(0.15)
                    : Color(red: 0.1, green: 0.12, blue: 0.2).opacity(0.3),
                radius: isHighlighted ? 20 : 10,
                y: isHighlighted ? 8 : 4
            )
        }
        .buttonStyle(SuckInButtonStyle(mode: mode, onPressChange: { pressed in
            if pressed {
                lastInteraction = Date()
            }
        }))
        .opacity(entrancePhase >= 1 ? 1.0 : 0.0)
        .offset(y: entrancePhase >= 1 ? 0 : 25)
        .animation(
            .easeOut(duration: 0.7).delay(delay),
            value: entrancePhase
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 버튼 탭 핸들러
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func buttonTapped(_ mode: AppMode) {
        lastInteraction = Date()

        // 선택 하이라이트
        highlightedMode = mode

        // 눈 반응
        eyeReact(mode)

        // 0.4초 후 실제 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            selectedMode = mode
            highlightedMode = nil
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 눈 인터랙션
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func eyeReact(_ mode: AppMode) {
        switch mode {
        case .hwadeuljjak:
            // 눈 번쩍임
            withAnimation(.easeIn(duration: 0.06)) {
                eyeFlashBrightness = 0.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.4)) {
                    eyeFlashBrightness = 0
                }
            }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        case .alarm:
            // 눈 좌우 미세 이동
            withAnimation(.easeInOut(duration: 0.15)) {
                eyeOffsetX = -3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    eyeOffsetX = 3
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    eyeOffsetX = 0
                }
            }

        case .timer:
            // 눈 느린 깜빡임
            withAnimation(.easeOut(duration: 0.3)) {
                eyeBlinkOpacity = 0.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.4)) {
                    eyeBlinkOpacity = 1.0
                }
            }

        case .report:
            // 눈 미세 수축
            withAnimation(.easeInOut(duration: 0.2)) {
                eyeIdleScale = 0.98
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    eyeIdleScale = 1.0
                }
            }

        case .settings:
            // 눈 약한 깜빡
            withAnimation(.easeOut(duration: 0.15)) {
                eyeBlinkOpacity = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    eyeBlinkOpacity = 1.0
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 유휴 감지
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startIdleTimer() {
        idleTimer?.invalidate()
        let it = Timer(timeInterval: 1.0, repeats: true) { [self] _ in
            guard selectedMode == nil else { return }

            let elapsed = Date().timeIntervalSince(lastInteraction)
            let threshold = Double.random(in: 5...10)

            if elapsed > threshold {
                idleEyeEffect()
                lastInteraction = Date() // 리셋
            }
        }
        RunLoop.main.add(it, forMode: .common)
        idleTimer = it
    }

    private func idleEyeEffect() {
        let effect = Int.random(in: 0...2)

        switch effect {
        case 0:
            // 미세 확대
            withAnimation(.easeInOut(duration: 2.0)) {
                eyeIdleScale = 1.025
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    eyeIdleScale = 1.0
                }
            }

        case 1:
            // 느린 깜빡임
            withAnimation(.easeOut(duration: 0.8)) {
                eyeBlinkOpacity = 0.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.6)) {
                    eyeBlinkOpacity = 1.0
                }
            }

        default:
            // 미세 밝아짐
            withAnimation(.easeInOut(duration: 1.5)) {
                eyeFlashBrightness = 0.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 1.5)) {
                    eyeFlashBrightness = 0
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 등장 애니메이션 (안개→형태→텍스트)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startEntrance() {
        // 0.3초: 안개 등장
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                entrancePhase = 1
            }
        }
        // 0.9초: 버튼 형태 등장
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.6)) {
                entrancePhase = 2
            }
        }
        // 1.5초: 텍스트 등장
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                entrancePhase = 3
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - ZAMKE Title
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var zamkeTitleView: some View {
        ZStack {
            // 레이어 1: 핏빛 잔상
            Image("01")
                .resizable()
                .scaledToFit()
                .frame(height: 360)
                .colorMultiply(.red.opacity(0.4))
                .opacity(0.08 * titleOpacity)
                .scaleEffect(titleScale * 1.3)
                .blur(radius: 20)
                .offset(x: titleShake * 2.5, y: 4)

            // 레이어 2: 유령 잔상
            Image("01")
                .resizable()
                .scaledToFit()
                .frame(height: 315)
                .opacity(0.06 * titleOpacity)
                .scaleEffect(titleScale * 1.12)
                .blur(radius: 7)
                .offset(x: -titleShake * 1.5, y: titleShake * 0.6)

            // 레이어 3: 메인
            Image("01")
                .resizable()
                .scaledToFit()
                .frame(height: 270)
                .opacity(0.88 * titleOpacity)
                .shadow(color: .white.opacity(0.10), radius: 6)
                .shadow(color: .red.opacity(0.08 * titleOpacity), radius: 28)
                .scaleEffect(titleScale)
                .blur(radius: titleBlur)
                .offset(x: titleShake)

            // 레이어 4: 피 선
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.red.opacity(0.18 * titleOpacity), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 200, height: 0.5)
                .offset(y: 52)
                .blur(radius: 0.5)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Title Animations
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startTitleAnimations() {
        withAnimation(.easeIn(duration: 1.5).delay(0.5)) {
            titleOpacity = 1.0
            titleBlur = 0.0
        }

        withAnimation(
            .easeInOut(duration: 3.5)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            titleScale = 1.12
        }

        startShake()
    }

    private func startShake() {
        func shake() {
            let pause = Double.random(in: 1.5...3.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
                let burstCount = Int.random(in: 4...8)
                burstShake(remaining: burstCount) { shake() }
            }
        }

        func burstShake(remaining: Int, completion: @escaping () -> Void) {
            guard remaining > 0 else {
                withAnimation(.easeOut(duration: 0.08)) { titleShake = 0 }
                completion()
                return
            }
            let d = Double.random(in: 0.03...0.06)
            let x = CGFloat.random(in: -5.0...5.0)
            withAnimation(.linear(duration: d)) {
                titleShake = x
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                burstShake(remaining: remaining - 1, completion: completion)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            shake()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Breathe
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startBreathe() {
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            breathe = 1.0
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Mode Router
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private func modeView(for mode: AppMode) -> some View {
        switch mode {
        case .hwadeuljjak:
            HwadeuljjakView(onBack: { selectedMode = nil })
        case .alarm:
            AlarmView { selectedMode = nil }
        case .timer:
            TimerView { selectedMode = nil }
        case .report:
            ReportView(onBack: { selectedMode = nil })
        case .settings:
            settingsView
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Settings
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var settingsView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { selectedMode = nil } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("홈")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(blueWhite.opacity(0.45))
                    }

                    Spacer()

                    Text("설정")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(blueWhite.opacity(0.9))

                    Spacer()

                    Color.clear.frame(width: 50, height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 0) {
                            settingsSectionHeader("앱 정보")
                            settingsRow(icon: "info.circle", title: "버전", trailing: "1.0.0")
                        }

                        VStack(spacing: 0) {
                            settingsSectionHeader("법적 고지")
                            settingsButton(icon: "doc.text", title: "이용약관") {
                                showTerms = true
                            }
                            Divider().background(Color.white.opacity(0.04)).padding(.leading, 52)
                            settingsButton(icon: "hand.raised", title: "개인정보 처리방침") {
                                showPrivacy = true
                            }
                        }

                        VStack(spacing: 0) {
                            settingsSectionHeader("지원")
                            settingsRow(icon: "envelope", title: "문의", trailing: "hello@kodamm.com")
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "이용약관", content: LegalTexts.termsOfService)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(title: "개인정보 처리방침", content: LegalTexts.privacyPolicy)
        }
    }

    // MARK: - Settings Components

    private func settingsSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundColor(blueWhite.opacity(0.3))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func settingsRow(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(blueWhite.opacity(0.3))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(blueWhite.opacity(0.8))

            Spacer()

            Text(trailing)
                .font(.system(size: 14))
                .foregroundColor(blueWhite.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func settingsButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(blueWhite.opacity(0.3))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(blueWhite.opacity(0.8))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(blueWhite.opacity(0.15))
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - AppMode (리포트 추가)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum AppMode: Int, CaseIterable, Identifiable {
    case hwadeuljjak = 0
    case alarm       = 1
    case timer       = 2
    case report      = 3
    case settings    = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .hwadeuljjak: return "화들짝"
        case .alarm:       return "알람"
        case .timer:       return "타이머"
        case .report:      return "리포트"
        case .settings:    return "설정"
        }
    }

    var sfSymbol: String {
        switch self {
        case .hwadeuljjak: return "eye.fill"
        case .alarm:       return "alarm.fill"
        case .timer:       return "timer"
        case .report:      return "chart.bar.fill"
        case .settings:    return "gearshape.fill"
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - SuckInButtonStyle (빨려 들어가는 터치)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct SuckInButtonStyle: ButtonStyle {
    let mode: AppMode
    var onPressChange: ((Bool) -> Void)?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.15, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressChange?(pressed)
                if pressed {
                    // 쿵 — 눌림
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    // 스읍 — 풀림
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - FogLayer (안개 효과)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct FogLayer: View {
    let seed: Int

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let fi = CGFloat(i)
                let baseSeed = CGFloat(seed)

                Ellipse()
                    .fill(Color.white.opacity(0.025 + Double(i) * 0.008))
                    .blur(radius: 20 + fi * 4)
                    .frame(
                        width: 70 + fi * 18,
                        height: 28 + fi * 8
                    )
                    .offset(
                        x: animate
                            ? (15 - fi * 8 + baseSeed * 3)
                            : (-15 + fi * 8 - baseSeed * 3),
                        y: animate
                            ? (-4 + fi * 2)
                            : (4 - fi * 2)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3.5 + Double(seed) * 0.6)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - GlitchText (글리치 + 미세 흔들림 + 깜빡임)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct GlitchText: View {
    let text: String
    var isHighlighted: Bool = false

    @State private var alive = true
    @State private var tremorX: CGFloat = 0
    @State private var tremorY: CGFloat = 0
    @State private var glitching = false
    @State private var dimmed = false

    // 푸른빛 흰색
    private let baseColor = Color(red: 0.82, green: 0.86, blue: 0.96)

    var body: some View {
        ZStack {
            // ── 글리치 레이어 (RGB 분리) ──
            if glitching {
                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.red.opacity(0.4))
                    .offset(x: CGFloat.random(in: -3...3), y: -1)

                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.cyan.opacity(0.3))
                    .offset(x: CGFloat.random(in: -2...2), y: 1)
            }

            // ── 메인 텍스트 ──
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(
                    isHighlighted
                    ? Color(red: 1.0, green: 0.3, blue: 0.25).opacity(dimmed ? 0.5 : 0.9)
                    : baseColor.opacity(dimmed ? 0.35 : 0.85)
                )
                .offset(
                    x: tremorX + (glitching ? CGFloat.random(in: -2...2) : 0),
                    y: tremorY
                )
        }
        .onAppear {
            startTremor()
            startBlink()
            startGlitch()
        }
        .onDisappear {
            alive = false
        }
    }

    // 미세 흔들림 (~0.5px)
    private func startTremor() {
        withAnimation(
            .easeInOut(duration: 0.14)
            .repeatForever(autoreverses: true)
        ) {
            tremorX = 0.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(
                .easeInOut(duration: 0.11)
                .repeatForever(autoreverses: true)
            ) {
                tremorY = 0.3
            }
        }
    }

    // 2~3초 간격 짧은 깜빡임
    private func startBlink() {
        func blink() {
            guard alive else { return }
            let wait = Double.random(in: 2.0...3.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
                guard alive else { return }
                dimmed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [self] in
                    dimmed = false
                    blink()
                }
            }
        }
        blink()
    }

    // 랜덤 글리치 (4~9초 간격)
    private func startGlitch() {
        func glitch() {
            guard alive else { return }
            let wait = Double.random(in: 4.0...9.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
                guard alive else { return }
                glitching = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.05...0.12)) { [self] in
                    glitching = false
                    glitch()
                }
            }
        }
        glitch()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Preview
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
