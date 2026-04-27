//
//  ContentView.swift
//  ZAMKE
//
//  메인 홈 — 의식 선택 화면
//  눈이 내려다보고, 아래에는 선택지만 존재한다.
//

import SwiftUI

struct ContentView: View {

    @State private var selectedMode: AppMode? = nil
    @State private var breathe: Double = 0.0
    @State private var buttonsAppeared = false
    @State private var showSnoozeHwadeuljjak = false
    private var snoozeManager: SnoozeManager { .shared }

    // 잠깨! 타이틀 애니메이션
    @State private var titleScale: CGFloat = 0.88
    @State private var titleOpacity: Double = 0.0
    @State private var titleShake: CGFloat = 0.0
    @State private var titleBlur: CGFloat = 3.0

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
        .fullScreenCover(isPresented: $showSnoozeHwadeuljjak) {
            HwadeuljjakView(onBack: {
                showSnoozeHwadeuljjak = false
            })
        }
        .onChange(of: snoozeManager.shouldLaunchHwadeuljjak) { _, shouldLaunch in
            if shouldLaunch {
                snoozeManager.shouldLaunchHwadeuljjak = false
                showSnoozeHwadeuljjak = true
            }
        }
    }

    // MARK: - Home

    private var homeView: some View {
        GeometryReader { geo in
            ZStack {
                // ── 0) 검정 배경 (이미지 여백 채움) ──
                Color.black.ignoresSafeArea()

                // ── 1) 배경 이미지 ──
                // 높은 opacity + 대비로 형태 구조 자체를 살림
                Image("02")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.95)
                    .contrast(1.22)
                    .brightness(0.03 + breathe * 0.015 - 0.008)
                    .ignoresSafeArea()

                // ── 2) 상단 조명 — 갓 윗부분 + 챙에 달빛이 내려오는 구조 ──
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.10), location: 0.0),
                        .init(color: Color.white.opacity(0.06), location: 0.12),
                        .init(color: Color.white.opacity(0.02), location: 0.25),
                        .init(color: Color.clear, location: 0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)
                .ignoresSafeArea()

                // ── 3) 얼굴 중간톤 — 중앙에 미세한 안개/연기 느낌 ──
                // 눈 주변 영역의 완전 검정을 깨뜨려 얼굴 형태 생성
                RadialGradient(
                    colors: [
                        Color(white: 0.18, opacity: 0.25),
                        Color(white: 0.12, opacity: 0.15),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.32),
                    startRadius: geo.size.width * 0.05,
                    endRadius: geo.size.width * 0.45
                )
                .blendMode(.screen)
                .ignoresSafeArea()

                // ── 4) 끈/구슬 영역 — 하단 중앙에 약한 빛으로 끈 가시성 확보 ──
                RadialGradient(
                    colors: [
                        Color(white: 0.15, opacity: 0.20),
                        Color(white: 0.10, opacity: 0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.58),
                    startRadius: geo.size.width * 0.02,
                    endRadius: geo.size.width * 0.30
                )
                .blendMode(.screen)
                .ignoresSafeArea()

                // ── 5) 하단 페이드 — UI 영역만 어둡게 (끈 영역은 보호) ──
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * 0.68)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.25),
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()

                // ── ZAMKE 타이틀 — 갓 위에 오싹하게 ──
                zamkeTitleView
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.22)

                // ── 6) UI ──
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()

                    // 버튼 영역 — 저승 세계 오브젝트
                    VStack(spacing: 14) {
                        ForEach(Array(AppMode.allCases.enumerated()), id: \.element.id) { index, mode in
                            RealmButton(mode: mode) {
                                selectedMode = mode
                            }
                            .opacity(buttonsAppeared ? 1.0 : 0.0)
                            .offset(y: buttonsAppeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.7)
                                .delay(Double(index) * 0.12),
                                value: buttonsAppeared
                            )
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer()
                        .frame(height: geo.size.height * 0.08)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startBreathe()
            startTitleAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                buttonsAppeared = true
            }
        }
    }

    // MARK: - ZAMKE Title (이미지 "01" + 오싹한 줌인/줌아웃 + 흔들림)

    private var zamkeTitleView: some View {
        ZStack {
            // 레이어 1: 핏빛 번짐 — 먼 잔상
            Image("01")
                .resizable()
                .scaledToFit()
                .frame(height: 360)
                .colorMultiply(.red.opacity(0.4))
                .opacity(0.08 * titleOpacity)
                .scaleEffect(titleScale * 1.3)
                .blur(radius: 20)
                .offset(x: titleShake * 2.5, y: 4)

            // 레이어 2: 유령 잔상 — 분열 느낌
            Image("01")
                .resizable()
                .scaledToFit()
                .frame(height: 315)
                .opacity(0.06 * titleOpacity)
                .scaleEffect(titleScale * 1.12)
                .blur(radius: 7)
                .offset(x: -titleShake * 1.5, y: titleShake * 0.6)

            // 레이어 3: 메인 잠깨 이미지
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

            // 레이어 4: 가는 붉은 선 — 피가 흐르는 듯한 선
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

    // MARK: - Title Animations

    private func startTitleAnimations() {
        // 1) 페이드 인
        withAnimation(.easeIn(duration: 1.5).delay(0.5)) {
            titleOpacity = 1.0
            titleBlur = 0.0
        }

        // 2) 줌인/줌아웃 반복 — 숨쉬듯
        withAnimation(
            .easeInOut(duration: 3.5)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            titleScale = 1.12
        }

        // 3) 강한 진동 — 오싹한 존재감
        startShake()
    }

    private func startShake() {
        func shake() {
            // 평온 → 갑자기 격렬한 떨림
            let pause = Double.random(in: 1.5...3.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
                let burstCount = Int.random(in: 4...8)
                burstShake(remaining: burstCount) {
                    shake()
                }
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

    // MARK: - Breathe

    private func startBreathe() {
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            breathe = 1.0
        }
    }

    // MARK: - Mode Router

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
            ReportView { selectedMode = nil }
        case .settings:
            settingsView
        }
    }

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showPremiumPurchase = false

    private var premiumStore: PremiumStore { .shared }

    private var settingsView: some View {
        ZStack {
            Color(red: 0.043, green: 0.059, blue: 0.102)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button { selectedMode = nil } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("홈")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    Text("설정")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.92))

                    Spacer()

                    Color.clear.frame(width: 50, height: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 24) {

                        // ── 프리미엄 ──
                        VStack(spacing: 0) {
                            settingsSectionHeader("프리미엄")

                            if premiumStore.isPremiumUnlocked {
                                // 이미 구매됨
                                HStack(spacing: 14) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(.green.opacity(0.8))
                                        .frame(width: 24)

                                    Text("화들짝 프리미엄")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))

                                    Spacer()

                                    Text("잠금 해제됨")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.green.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            } else {
                                // 구매 버튼
                                Button {
                                    showPremiumPurchase = true
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 15))
                                            .foregroundColor(.yellow.opacity(0.8))
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("화들짝 프리미엄")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white.opacity(0.85))
                                            Text("공포 미션으로 확실하게 기상")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.35))
                                        }

                                        Spacer()

                                        Text(premiumStore.displayPrice)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.yellow.opacity(0.9))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(Color.yellow.opacity(0.10))
                                            )

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.2))
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(height: 56)
                                }
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)

                                // 복원 버튼
                                Button {
                                    Task { await premiumStore.restore() }
                                } label: {
                                    Text("이전 구매 복원")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.top, 6)
                            }
                        }

                        // ── 앱 정보 ──
                        VStack(spacing: 0) {
                            settingsSectionHeader("앱 정보")

                            settingsRow(icon: "info.circle", title: "버전", trailing: "1.0.0")
                        }

                        // ── 법적 문서 ──
                        VStack(spacing: 0) {
                            settingsSectionHeader("법적 고지")

                            settingsButton(icon: "doc.text", title: "이용약관") {
                                showTerms = true
                            }

                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)

                            settingsButton(icon: "hand.raised", title: "개인정보 처리방침") {
                                showPrivacy = true
                            }
                        }

                        // ── 문의 ──
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
        .sheet(isPresented: $showPremiumPurchase) {
            PremiumPurchaseView()
        }
    }

    // MARK: - Settings Components

    private func settingsSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundColor(.white.opacity(0.4))
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
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Spacer()

            Text(trailing)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func settingsButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - App Mode

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

}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
