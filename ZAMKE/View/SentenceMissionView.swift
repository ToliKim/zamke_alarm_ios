//
//  SentenceMissionView.swift
//  ZAMKE
//
//  미션 3: 각성 — 심연 공간에서 떠다니는 단어를 조합하라
//
//  배경은 안개와 소용돌이가 숨쉬는 심연.
//  단어들은 흐름에 실려 움직이며, 정답은 미세하게 도망치고
//  비정답은 중립적으로 떠돈다.
//  시간이 흐를수록 어둠이 짙어지고, 심연 속 눈이 나타난다.
//
//  ⚠️ 안정성: .task {}, gameStarted, onDisappear cleanup
//

import SwiftUI

// MARK: - 떠다니는 단어 모델

private struct FloatingWord: Identifiable {
    let id = UUID()
    let text: String
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var placed: Bool = false
    var wrongFlash: Bool = false
    var opacity: Double = 1.0
    /// 흡수 애니메이션 중
    var absorbing: Bool = false
    var absorbTargetX: CGFloat = 0
    var absorbTargetY: CGFloat = 0
}

// MARK: - 심연의 눈 모델

private struct AbyssEye: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double = 0
    var pupilOffsetX: CGFloat = 0
    var pupilOffsetY: CGFloat = 0
}

// MARK: - 안개 입자 모델

private struct FogParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var opacity: Double
    var vx: CGFloat
    var vy: CGFloat
}

@MainActor
struct SentenceMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 페이즈 ──
    enum Phase { case ready, playing, success, failed }

    @State private var phase: Phase = .ready
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 3

    // ── 문장 데이터 ──
    @State private var currentSentence: [String] = []
    @State private var floatingWords: [FloatingWord] = []
    @State private var slotWords: [String] = []

    // ── 타이머 ──
    @State private var roundTimer: Timer?
    @State private var moveTimer: Timer?
    @State private var timeLeft: Double = 0
    @State private var timeLimit: Double = 0
    @State private var renderTick: Int = 0

    // ── 성공 연출 ──
    @State private var successScale: CGFloat = 0.8
    @State private var successOpacity: Double = 0

    // ── 최종 축하 연출 (03 이미지) ──
    @State private var showCelebration = false
    @State private var celebImgScale: CGFloat = 0.3
    @State private var celebImgOpacity: Double = 0
    @State private var celebTextOpacity: Double = 0
    @State private var celebGlow: Double = 0

    // ── 저승사자 등장 (오답 시) ──
    @State private var reaperVisible: Bool = false
    @State private var reaperShakeX: CGFloat = 0
    @State private var reaperShakeY: CGFloat = 0
    @State private var reaperOpacity: Double = 0
    @State private var reaperScale: CGFloat = 1.6
    @State private var reaperShakeTimer: Timer?

    // ── 심연 배경 ──
    @State private var fogParticles: [FogParticle] = []
    @State private var abyssEyes: [AbyssEye] = []
    @State private var flowAngle: CGFloat = 0          // 전체 흐름 방향 (라디안)
    @State private var flowSpeed: CGFloat = 0.6        // 전체 흐름 속력
    @State private var fogDensity: Double = 0.15       // 안개 밀도 (시간에 따라 증가)
    @State private var abyssDepth: Double = 0.0        // 심연 깊이 (어둠 정도)
    @State private var swirlPhase: Double = 0          // 소용돌이 위상
    @State private var eyeSpawnTimer: Timer?
    @State private var fogTimer: Timer?

    // ── 화면 흔들림 ──
    @State private var screenShakeX: CGFloat = 0
    @State private var screenShakeY: CGFloat = 0
    @State private var screenShakeTimer: Timer?

    // ── 성공 시 흐름 정지 & 정렬 ──
    @State private var flowFrozen: Bool = false
    @State private var fogClearing: Bool = false

    // ── 화면 ──
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var gameStarted = false

    // 하단 슬롯 높이
    private let slotBarHeight: CGFloat = 70

    // 단어 떠다니는 영역
    private var floatTop: CGFloat { 80 }
    private var floatBottom: CGFloat { screenH - slotBarHeight - 90 }

    // ── 경과 시간 (긴장 고조) ──
    @State private var elapsedSinceRoundStart: Double = 0

    // ── 라운드별 제한시간 — 넉넉하게 ──
    private func timeLimitForRound(_ r: Int) -> Double {
        switch r {
        case 0: return 30.0
        case 1: return 25.0
        default: return 60.0  // 3라운드: 직접 입력 → 충분한 시간
        }
    }

    // ── 라운드별 기본 단어 속도 — 느리게 ──
    private func baseWordSpeed(_ r: Int) -> CGFloat {
        switch r {
        case 0: return 0.5
        case 1: return 0.8
        default: return 0.5
        }
    }

    // ── 3라운드(마지막)는 직접 입력 모드인지 ──
    private var isTypingRound: Bool { round == 2 }

    // ── 직접 입력 상태 ──
    @State private var typingInput: String = ""
    @State private var typingShake: CGFloat = 0
    @FocusState private var typingFocused: Bool

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 문장 풀
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private let sentences: [[String]] = [
        // ── 기상 ──
        ["지금", "일어나는", "사람이", "하루를", "바꾼다"],
        ["아침을", "잡는", "사람이", "인생을", "잡는다"],
        ["일어난", "순간", "이미", "절반은", "성공이다"],
        ["지금", "시작하는", "사람이", "결국", "이긴다"],
        ["일어나는", "선택이", "미래를", "결정한다"],
        ["잠에서", "벗어나야", "삶이", "시작된다"],
        ["지금", "움직이지", "않으면", "아무것도", "변하지", "않는다"],
        ["눈을", "뜨는", "순간", "기회는", "시작된다"],
        ["일어나지", "않으면", "아무", "일도", "일어나지", "않는다"],
        ["지금", "이", "순간이", "가장", "중요한", "시간이다"],
        // ── 집중 ──
        ["집중하는", "사람이", "결과를", "만든다"],
        ["흐트러지지", "않는", "마음이", "길을", "만든다"],
        ["집중은", "재능보다", "강한", "힘이다"],
        ["한", "번의", "집중이", "하루를", "바꾼다"],
        ["지금", "집중하는", "것이", "미래를", "만든다"],
        ["산만함을", "버리는", "순간", "성장이", "시작된다"],
        ["집중하는", "시간이", "인생의", "차이를", "만든다"],
        ["지금", "붙잡는", "것이", "결과를", "만든다"],
        ["집중하는", "사람이", "결국", "앞서간다"],
        ["흐름을", "놓치지", "않는", "사람이", "이긴다"],
        // ── 행동 ──
        ["지금", "행동하는", "것이", "모든", "것을", "바꾼다"],
        ["생각보다", "행동이", "먼저다"],
        ["작게라도", "시작하는", "사람이", "강하다"],
        ["미루지", "않는", "사람이", "결과를", "만든다"],
        ["지금", "하는", "행동이", "인생을", "만든다"],
        ["움직이는", "사람이", "기회를", "잡는다"],
        ["실행하는", "사람이", "세상을", "바꾼다"],
        ["지금", "하지", "않으면", "아무것도", "바뀌지", "않는다"],
        ["행동하는", "순간", "변화는", "시작된다"],
        ["시작하는", "용기가", "성공을", "부른다"],
        // ── 끈기 ──
        ["끝까지", "하는", "사람이", "결국", "해낸다"],
        ["포기하지", "않는", "사람이", "결과를", "만든다"],
        ["버티는", "힘이", "성공을", "만든다"],
        ["마지막까지", "가는", "사람이", "이긴다"],
        ["지금", "버티는", "시간이", "미래를", "만든다"],
        ["성공은", "반복된", "행동에서", "만들어진다"],
        ["꾸준함이", "결국", "차이를", "만든다"],
        ["작은", "성공이", "큰", "변화를", "만든다"],
        ["지금", "쌓는", "것이", "결과가", "된다"],
        ["계속하는", "사람이", "결국", "도달한다"],
        // ── 종합 ──
        ["오늘을", "이기는", "사람이", "내일을", "가진다"],
        ["하루를", "제대로", "쓰는", "사람이", "인생을", "바꾼다"],
        ["지금", "이", "선택이", "모든", "것을", "바꾼다"],
        ["오늘을", "놓치면", "내일도", "없다"],
        ["지금", "이", "순간이", "인생의", "방향이다"],
        ["일어난", "사람이", "이미", "앞서", "있다"],
        ["집중하는", "사람이", "결국", "올라간다"],
        ["행동하는", "사람이", "기회를", "만든다"],
        ["버티는", "사람이", "결국", "성공한다"],
        ["지금", "하는", "것이", "전부를", "바꾼다"],
    ]

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        GeometryReader { geo in
            let _ = renderTick

            ZStack {
                // ── 0) 04 이미지 배경 + 심연 오버레이 ──
                abyssBackground(geo: geo)
                    .allowsHitTesting(false)

                // ── 1) 상단 UI (터치 통과) ──
                VStack(spacing: 0) {
                    // 라운드 인디케이터
                    HStack(spacing: 6) {
                        ForEach(0..<totalRounds, id: \.self) { i in
                            Circle()
                                .fill(i < round
                                      ? Color.green.opacity(0.7)
                                      : (i == round
                                         ? Color.white.opacity(0.6)
                                         : Color.white.opacity(0.12)))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 16)

                    // 타이머 바
                    if phase == .playing {
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(timeLeft < 3.0
                                          ? Color.red.opacity(0.8)
                                          : Color.green.opacity(0.5))
                                    .frame(width: barGeo.size.width * max(0, timeLeft / timeLimit), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                    }

                    Spacer()
                }
                .allowsHitTesting(false)

                // ── 2) 떠다니는 단어들 (1~2라운드) ──
                if (phase == .playing || phase == .success) && !isTypingRound {
                    ForEach(floatingWords) { word in
                        if !word.placed && !word.absorbing {
                            abyssWordBubble(word)
                                .position(x: word.x, y: word.y)
                                .opacity(word.opacity)
                                .onTapGesture { wordTapped(word) }
                        }
                    }
                }

                // ── 2b) 직접 입력 UI (3라운드) ──
                if (phase == .playing || phase == .success) && isTypingRound {
                    typingRoundView
                }

                // ── 3) 하단 슬롯 (1~2라운드만) ──
                if (phase == .playing || phase == .success) && !isTypingRound {
                    VStack {
                        Spacer()
                        slotBar
                            .padding(.bottom, 50)
                    }
                    .allowsHitTesting(false)
                }

                // ── 4) 심연의 눈 ──
                ForEach(abyssEyes) { eye in
                    abyssEyeView(eye)
                        .position(x: eye.x, y: eye.y)
                        .opacity(eye.opacity)
                        .scaleEffect(eye.scale)
                }
                .allowsHitTesting(false)

                // ── 5) 저승사자 등장 (오답 시) ──
                if reaperVisible {
                    ZStack {
                        Image("02")
                            .resizable()
                            .scaledToFill()
                            .frame(width: screenW, height: screenH)
                            .scaleEffect(reaperScale)
                            .offset(x: reaperShakeX, y: reaperShakeY)
                            .opacity(reaperOpacity)
                            .colorMultiply(Color(red: 1.0, green: 0.06, blue: 0.02))
                            .clipped()

                        Color.red.opacity(reaperOpacity * 0.25)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // ── 6) 성공/실패/대기 텍스트 ──
                if phase == .ready {
                    Text("…")
                        .font(.system(size: 24, weight: .black).width(.condensed))
                        .foregroundColor(.white.opacity(0.12))
                }

                if phase == .success {
                    Text("완성")
                        .font(.system(size: 44, weight: .black).width(.condensed))
                        .foregroundColor(.green.opacity(0.9))
                        .shadow(color: .green.opacity(0.5), radius: 25)
                        .scaleEffect(successScale)
                        .opacity(successOpacity)
                }

                if phase == .failed {
                    Color.red.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    Text("시간 초과")
                        .font(.system(size: 40, weight: .black).width(.condensed))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.6), radius: 30)
                }

                // ── 7) 최종 축하 (03 이미지 줌인) ──
                if showCelebration {
                    celebrationView
                }
            }
            .offset(x: screenShakeX, y: screenShakeY)
            .task {
                screenW = geo.size.width
                screenH = geo.size.height
                guard !gameStarted else { return }
                gameStarted = true
                initFogParticles()
                startGame()
            }
            .onDisappear { cleanup() }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심연 배경 (04 이미지 + 오버레이)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func abyssBackground(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height

        return ZStack {
            // ── 0) 검정 배경 ──
            Color.black.ignoresSafeArea()

            // ── 1) 04 이미지 — 120% 확대, 중앙 구멍이 핵심 ──
            Image("04")
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .scaleEffect(1.2)
                .opacity(0.85 - abyssDepth * 0.2)
                .clipped()
                .ignoresSafeArea()

            // ── 2) 중앙 구멍 glow — 단어가 나오는 심연의 입구 ──
            RadialGradient(
                colors: [
                    Color(red: 0.06, green: 0.03, blue: 0.12, opacity: 0.7),
                    Color(red: 0.04, green: 0.02, blue: 0.08, opacity: 0.4),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: w * 0.35
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // ── 3) 중앙 구멍 맥동 — 숨 쉬듯 ──
            RadialGradient(
                colors: [
                    Color(red: 0.10, green: 0.04, blue: 0.18,
                          opacity: fogDensity * sin(swirlPhase * 0.8) * 0.3 + 0.2),
                    Color(red: 0.06, green: 0.02, blue: 0.10,
                          opacity: fogDensity * 0.15),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 5 + CGFloat(sin(swirlPhase * 1.2)) * 8,
                endRadius: w * 0.25
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // ── 4) 소용돌이 안개 — 이미지 위에 유동적 분위기 ──
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.08, green: 0.04, blue: 0.15, opacity: fogDensity * 0.5),
                            Color(red: 0.05, green: 0.02, blue: 0.10, opacity: fogDensity * 0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: w * 0.8, height: h * 0.35)
                .rotationEffect(.radians(swirlPhase * 0.12))
                .offset(x: sin(swirlPhase * 0.3) * 30,
                         y: cos(swirlPhase * 0.25) * 25 + h * 0.05)
                .blendMode(.screen)
                .ignoresSafeArea()

            // ── 5) 붉은 심연 (라운드 진행에 따라) ──
            if abyssDepth > 0.1 {
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.02, blue: 0.04, opacity: abyssDepth * 0.4),
                        Color(red: 0.10, green: 0.01, blue: 0.02, opacity: abyssDepth * 0.2),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 10,
                    endRadius: w * 0.5
                )
                .blendMode(.screen)
                .ignoresSafeArea()
            }

            // ── 6) 안개 입자들 ──
            ForEach(fogParticles) { p in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.10, green: 0.06, blue: 0.15,
                                      opacity: p.opacity * fogDensity * 2.0),
                                Color(red: 0.06, green: 0.04, blue: 0.10,
                                      opacity: p.opacity * fogDensity * 0.8),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: p.radius
                        )
                    )
                    .frame(width: p.radius * 2.2, height: p.radius * 2.2)
                    .position(x: p.x, y: p.y)
                    .blendMode(.screen)
            }

            // ── 7) 비네팅 — 이미지 가장자리 어둡게 ──
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7)
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: w * 0.3,
                endRadius: w * 0.75
            )
            .ignoresSafeArea()

            // ── 8) 실패 압박 비네팅 ──
            if phase == .playing {
                let urgency = max(0, 1.0 - timeLeft / timeLimit)
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(urgency * 0.4),
                        Color.black.opacity(urgency * 0.8)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: w * (0.3 - urgency * 0.1),
                    endRadius: w * 0.7
                )
                .ignoresSafeArea()

                if urgency > 0.5 {
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.red.opacity((urgency - 0.5) * 0.12),
                            Color.red.opacity((urgency - 0.5) * 0.2)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: w * 0.35,
                        endRadius: w * 0.75
                    )
                    .ignoresSafeArea()
                }
            }

            // ── 9) 안개 클리어링 ──
            if fogClearing {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심연의 눈
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func abyssEyeView(_ eye: AbyssEye) -> some View {
        ZStack {
            // 먼 glow — 안개 속에서 빛나는 느낌
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.4, green: 0.04, blue: 0.06, opacity: 0.15),
                            Color(red: 0.2, green: 0.02, blue: 0.03, opacity: 0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 70)

            // 눈 외곽 — 흰자
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.18, opacity: 0.7),
                            Color(white: 0.10, opacity: 0.4),
                            Color(white: 0.05, opacity: 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: 30
                    )
                )
                .frame(width: 56, height: 30)

            // 홍채
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.7, green: 0.06, blue: 0.08, opacity: 0.95),
                            Color(red: 0.5, green: 0.04, blue: 0.06, opacity: 0.7),
                            Color(red: 0.25, green: 0.02, blue: 0.03, opacity: 0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 24, height: 22)

            // 동공
            Ellipse()
                .fill(Color.black)
                .frame(width: 9, height: 14)
                .offset(x: eye.pupilOffsetX, y: eye.pupilOffsetY)

            // 하이라이트
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 3, height: 3)
                .offset(x: 4, y: -4)

            // 두 번째 하이라이트 (작은)
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1.5, height: 1.5)
                .offset(x: -2, y: 2)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심연 단어 버블
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func abyssWordBubble(_ word: FloatingWord) -> some View {
        let isNextCorrect = slotWords.count < currentSentence.count
            && word.text == currentSentence[slotWords.count]

        return ZStack {
            // 배경 glow — 다음 정답은 미세하게 빛남
            if isNextCorrect {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .blur(radius: 8)
                    .frame(width: 100, height: 50)
            }

            Text(word.text)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(
                    word.wrongFlash
                    ? .red
                    : .white.opacity(isNextCorrect ? 0.95 : 0.7)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            word.wrongFlash
                            ? Color.red.opacity(0.3)
                            : Color(white: 0.08, opacity: 0.6)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            word.wrongFlash
                            ? Color.red.opacity(0.7)
                            : Color.white.opacity(isNextCorrect ? 0.3 : 0.12),
                            lineWidth: word.wrongFlash ? 1.5 : 1
                        )
                )
                .shadow(
                    color: word.wrongFlash
                        ? .red.opacity(0.5)
                        : (isNextCorrect ? .white.opacity(0.08) : .clear),
                    radius: word.wrongFlash ? 14 : 6
                )
        }
        .contentShape(Rectangle())
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 하단 슬롯 바
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var slotBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(0..<currentSentence.count, id: \.self) { i in
                    if i < slotWords.count {
                        Text(slotWords[i])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(phase == .success ? 0.5 : 0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    } else if i == slotWords.count {
                        Text("?")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.2))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.4),
                                            style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                            )
                    } else {
                        Text("?")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.08))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1),
                                            style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 축하 뷰
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var celebrationView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("03")
                .resizable()
                .scaledToFit()
                .scaleEffect(celebImgScale)
                .opacity(celebImgOpacity)
                .shadow(color: .green.opacity(celebGlow * 0.4), radius: 30)

            RadialGradient(
                colors: [
                    Color.green.opacity(celebGlow * 0.12),
                    Color.green.opacity(celebGlow * 0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 280
            )
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Spacer()

                Text("각  성  완  료")
                    .font(.system(size: 28, weight: .thin, design: .serif))
                    .tracking(10)
                    .foregroundColor(.green.opacity(0.8))
                    .shadow(color: .green.opacity(0.3), radius: 15)

                Text("— 모든 문장을 완성했습니다 —")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.35))

                Spacer().frame(height: 80)
            }
            .opacity(celebTextOpacity)
        }
        .allowsHitTesting(false)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 직접 입력 라운드 뷰 (3라운드)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var typingRoundView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 명언 표시
            Text("이 명언을 직접 입력하세요")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)

            // 문장 보여주기
            Text(currentSentence.joined(separator: " "))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .shadow(color: .white.opacity(0.1), radius: 8)

            // 입력 필드
            TextField("", text: $typingInput, prompt:
                Text("여기에 입력...")
                    .foregroundColor(.white.opacity(0.2))
            )
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        typingInput.isEmpty
                            ? Color.white.opacity(0.12)
                            : Color.green.opacity(0.4),
                        lineWidth: 1.5
                    )
            )
            .focused($typingFocused)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .offset(x: typingShake)
            .padding(.horizontal, 24)

            // 제출 버튼
            Button {
                checkTypingInput()
            } label: {
                Text("확  인")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(4)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.8))
                    )
                    .shadow(color: .green.opacity(0.3), radius: 10)
            }

            Spacer()
            Spacer()
        }
    }

    private func checkTypingInput() {
        let answer = currentSentence.joined(separator: " ")
        // 공백 정규화 비교
        let cleaned = typingInput.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let answerCleaned = answer.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if cleaned == answerCleaned {
            // 정답!
            typingFocused = false
            audioEngine?.resumeFromTyping()
            roundCleared()
        } else {
            // 오답 — 흔들림 + 시간 감소
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioEngine?.fireFailureBlast()
            timeLeft = max(0, timeLeft - 3.0)
            showReaperFlash()
            triggerScreenShake()

            // 입력 필드 흔들림
            withAnimation(.default) { typingShake = -12 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.default) { typingShake = 10 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.default) { typingShake = -6 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.default) { typingShake = 0 }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 안개 입자 초기화
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func initFogParticles() {
        guard screenW > 0 else { return }
        var particles: [FogParticle] = []
        // 큰 안개 구체 — 심연의 부피감
        for _ in 0..<10 {
            particles.append(FogParticle(
                x: CGFloat.random(in: -50...(screenW + 50)),
                y: CGFloat.random(in: -50...(screenH + 50)),
                radius: CGFloat.random(in: 100...200),
                opacity: Double.random(in: 0.15...0.45),
                vx: CGFloat.random(in: -0.25...0.25),
                vy: CGFloat.random(in: -0.15...0.15)
            ))
        }
        // 작은 안개 — 디테일
        for _ in 0..<14 {
            particles.append(FogParticle(
                x: CGFloat.random(in: 0...screenW),
                y: CGFloat.random(in: 0...screenH),
                radius: CGFloat.random(in: 30...80),
                opacity: Double.random(in: 0.1...0.35),
                vx: CGFloat.random(in: -0.4...0.4),
                vy: CGFloat.random(in: -0.3...0.3)
            ))
        }
        fogParticles = particles
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 게임 로직
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startGame() {
        alive = true
        round = 0
        startRound()
    }

    private func startRound() {
        guard alive, round < totalRounds else { return }
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        eyeSpawnTimer?.invalidate()
        phase = .ready
        slotWords = []
        floatingWords = []
        successScale = 0.8
        successOpacity = 0
        flowFrozen = false
        fogClearing = false
        elapsedSinceRoundStart = 0
        abyssEyes = []

        // 라운드에 따른 심연 깊이 초기화
        abyssDepth = Double(round) * 0.15
        fogDensity = 0.15 + Double(round) * 0.05

        // 흐름 방향 랜덤 초기화
        flowAngle = CGFloat.random(in: 0...(2 * .pi))
        flowSpeed = 0.6 + CGFloat(round) * 0.15

        currentSentence = sentences.randomElement()!
        typingInput = ""
        typingShake = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            guard alive else { return }
            if isTypingRound {
                // 3라운드: 직접 입력 모드
                // 키보드 + AVAudioEngine 충돌 방지 — 오디오 뮤트
                audioEngine?.pauseForTyping()
                phase = .playing
                timeLimit = timeLimitForRound(round)
                timeLeft = timeLimit
                startTimer()
                startWordMovement()  // 배경 안개/눈 업데이트용
                startEyeSpawner()
                // 키보드 자동 포커스
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    typingFocused = true
                }
            } else {
                // 1~2라운드: 단어 선택 모드
                spawnFloatingWords()
                phase = .playing
                timeLimit = timeLimitForRound(round)
                timeLeft = timeLimit
                startTimer()
                startWordMovement()
                startEyeSpawner()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 단어 스폰 (문장 단어만)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // 중앙 구멍 위치 (04 이미지 기준)
    private var holeCenterX: CGFloat { screenW * 0.5 }
    private var holeCenterY: CGFloat { screenH * 0.42 }

    private func spawnFloatingWords() {
        let margin: CGFloat = 60
        let top = floatTop + 30
        let bot = floatBottom - 30

        var words: [FloatingWord] = []
        let shuffled = currentSentence.shuffled()

        // ── 중앙 구멍에서 방사형으로 튀어나옴 ──
        for (idx, text) in shuffled.enumerated() {
            // 시작: 중앙 구멍 근처 (약간의 랜덤)
            let startX = holeCenterX + CGFloat.random(in: -15...15)
            let startY = holeCenterY + CGFloat.random(in: -15...15)

            // 방사형 방향으로 튕겨나가는 속도
            let angle = (CGFloat.pi * 2.0 / CGFloat(shuffled.count)) * CGFloat(idx)
                + CGFloat.random(in: -0.3...0.3)
            let spd = baseWordSpeed(round) * CGFloat.random(in: 2.5...4.0)
            let vx = cos(angle) * spd
            let vy = sin(angle) * spd

            // 최종 목표 위치 (분산된 곳에 안착)
            let targetX = max(margin, min(screenW - margin,
                holeCenterX + cos(angle) * CGFloat.random(in: 100...(screenW * 0.4))))
            let targetY = max(top, min(bot,
                holeCenterY + sin(angle) * CGFloat.random(in: 80...(screenH * 0.25))))

            var word = FloatingWord(text: text, x: startX, y: startY, vx: vx, vy: vy)
            word.opacity = 0  // 처음엔 투명 → 등장 애니메이션
            word.absorbTargetX = targetX
            word.absorbTargetY = targetY
            words.append(word)
        }

        floatingWords = words

        // ── 시차를 두고 하나씩 등장 ──
        for (idx, _) in shuffled.enumerated() {
            let delay = Double(idx) * 0.15 + 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                guard alive, idx < floatingWords.count else { return }
                floatingWords[idx].opacity = 1.0
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 단어 이동 (흐름 기반)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startWordMovement() {
        moveTimer?.invalidate()
        let mt = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive else {
                moveTimer?.invalidate()
                return
            }
            if phase == .playing {
                moveWordsWithFlow()
                updateFogParticles()
                updateAbyssAtmosphere()
            }
            renderTick &+= 1
        }
        RunLoop.main.add(mt, forMode: .common)
        moveTimer = mt
    }

    private func moveWordsWithFlow() {
        let margin: CGFloat = 40
        let top = floatTop
        let bot = floatBottom

        // 흐름 방향 미세 변동 (소용돌이 느낌)
        flowAngle += CGFloat.random(in: -0.008...0.008)
        swirlPhase += 0.015

        let flowVX = cos(flowAngle) * flowSpeed
        let flowVY = sin(flowAngle) * flowSpeed

        let nextIdx = slotWords.count
        let nextCorrectText = nextIdx < currentSentence.count ? currentSentence[nextIdx] : nil

        let centerX = holeCenterX
        let centerY = holeCenterY

        for i in floatingWords.indices {
            guard !floatingWords[i].placed, !floatingWords[i].absorbing else { continue }

            let isNextCorrect = floatingWords[i].text == nextCorrectText

            if isNextCorrect {
                // ── 정답 단어: 흐름을 거스르며 미세하게 도망 ──
                let fleeFactor: CGFloat = 0.12
                let awayX = floatingWords[i].x - centerX
                let awayY = floatingWords[i].y - centerY
                let dist = max(sqrt(awayX * awayX + awayY * awayY), 1)
                let nx = awayX / dist
                let ny = awayY / dist

                // 흐름 반대 방향 + 중심에서 도망
                floatingWords[i].vx += (-flowVX * 0.02) + nx * fleeFactor
                floatingWords[i].vy += (-flowVY * 0.02) + ny * fleeFactor

                // 미세한 불규칙 움직임 추가
                floatingWords[i].vx += CGFloat.random(in: -0.15...0.15)
                floatingWords[i].vy += CGFloat.random(in: -0.15...0.15)
            } else {
                // ── 비정답 단어: 흐름에 실려 중립적으로 움직임 ──
                floatingWords[i].vx += flowVX * 0.03
                floatingWords[i].vy += flowVY * 0.03

                // 약간의 랜덤 변동
                floatingWords[i].vx += CGFloat.random(in: -0.06...0.06)
                floatingWords[i].vy += CGFloat.random(in: -0.06...0.06)
            }

            // 위치 업데이트
            floatingWords[i].x += floatingWords[i].vx
            floatingWords[i].y += floatingWords[i].vy

            // 벽 바운스 (부드러운 반사)
            if floatingWords[i].x < margin {
                floatingWords[i].x = margin
                floatingWords[i].vx = abs(floatingWords[i].vx) * 0.8
            }
            if floatingWords[i].x > screenW - margin {
                floatingWords[i].x = screenW - margin
                floatingWords[i].vx = -abs(floatingWords[i].vx) * 0.8
            }
            if floatingWords[i].y < top {
                floatingWords[i].y = top
                floatingWords[i].vy = abs(floatingWords[i].vy) * 0.8
            }
            if floatingWords[i].y > bot {
                floatingWords[i].y = bot
                floatingWords[i].vy = -abs(floatingWords[i].vy) * 0.8
            }

            // 속도 제한 (정답 단어는 약간 더 빠를 수 있음)
            let maxSpd = baseWordSpeed(round) * (isNextCorrect ? 2.0 : 1.5)
            let spd = sqrt(floatingWords[i].vx * floatingWords[i].vx + floatingWords[i].vy * floatingWords[i].vy)
            if spd > maxSpd {
                floatingWords[i].vx = floatingWords[i].vx / spd * maxSpd
                floatingWords[i].vy = floatingWords[i].vy / spd * maxSpd
            }

            // 감쇠 (자연스러운 흐름 유지)
            floatingWords[i].vx *= 0.98
            floatingWords[i].vy *= 0.98
        }

        // ── 충돌 회피 — 단어끼리 겹치면 밀어냄 ──
        let minDist: CGFloat = 90   // 단어 간 최소 거리
        for i in floatingWords.indices {
            guard !floatingWords[i].placed, !floatingWords[i].absorbing else { continue }
            for j in (i + 1)..<floatingWords.count {
                guard !floatingWords[j].placed, !floatingWords[j].absorbing else { continue }
                let dx = floatingWords[j].x - floatingWords[i].x
                let dy = floatingWords[j].y - floatingWords[i].y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < minDist && dist > 0.1 {
                    let overlap = (minDist - dist) / 2.0
                    let nx = dx / dist
                    let ny = dy / dist
                    let push: CGFloat = 0.5
                    floatingWords[i].x -= nx * overlap * push
                    floatingWords[i].y -= ny * overlap * push
                    floatingWords[j].x += nx * overlap * push
                    floatingWords[j].y += ny * overlap * push
                    // 속도 반영
                    floatingWords[i].vx -= nx * 0.15
                    floatingWords[i].vy -= ny * 0.15
                    floatingWords[j].vx += nx * 0.15
                    floatingWords[j].vy += ny * 0.15
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 안개 입자 업데이트
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func updateFogParticles() {
        for i in fogParticles.indices {
            // 흐름 방향으로 느리게 이동
            fogParticles[i].x += fogParticles[i].vx + cos(flowAngle) * 0.15
            fogParticles[i].y += fogParticles[i].vy + sin(flowAngle) * 0.15

            // 화면 밖으로 나가면 반대편에서 재진입
            if fogParticles[i].x < -fogParticles[i].radius {
                fogParticles[i].x = screenW + fogParticles[i].radius
            }
            if fogParticles[i].x > screenW + fogParticles[i].radius {
                fogParticles[i].x = -fogParticles[i].radius
            }
            if fogParticles[i].y < -fogParticles[i].radius {
                fogParticles[i].y = screenH + fogParticles[i].radius
            }
            if fogParticles[i].y > screenH + fogParticles[i].radius {
                fogParticles[i].y = -fogParticles[i].radius
            }

            // opacity 미세 변동
            fogParticles[i].opacity += Double.random(in: -0.005...0.005)
            fogParticles[i].opacity = max(0.05, min(0.5, fogParticles[i].opacity))
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심연 분위기 업데이트 (긴장 고조)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func updateAbyssAtmosphere() {
        elapsedSinceRoundStart += 0.033

        // 시간이 흐를수록 안개 밀도 증가
        let timeProgress = max(0, 1.0 - timeLeft / timeLimit)
        fogDensity = (0.15 + Double(round) * 0.05) + timeProgress * 0.25

        // 심연 깊이 (어둠) 증가
        abyssDepth = (Double(round) * 0.15) + timeProgress * 0.3

        // 흐름 속도도 시간 경과에 따라 미세 증가
        let baseFSpeed = 0.6 + CGFloat(round) * 0.15
        flowSpeed = baseFSpeed + CGFloat(timeProgress) * 0.4
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 심연의 눈 스포너
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startEyeSpawner() {
        eyeSpawnTimer?.invalidate()

        func scheduleNext() {
            guard alive, phase == .playing else { return }

            // 라운드 후반일수록 더 자주 등장
            let timeProgress = max(0, 1.0 - timeLeft / timeLimit)
            let minDelay = max(2.0, 5.0 - Double(round) * 0.5 - timeProgress * 2.0)
            let maxDelay = max(3.0, 8.0 - Double(round) * 0.8 - timeProgress * 3.0)
            let delay = Double.random(in: minDelay...maxDelay)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                guard alive, phase == .playing else { return }
                spawnAbyssEye()
                scheduleNext()
            }
        }

        // 첫 눈은 3초 후부터
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [self] in
            guard alive, phase == .playing else { return }
            spawnAbyssEye()
            scheduleNext()
        }
    }

    private func spawnAbyssEye() {
        // 최대 3개까지만
        guard abyssEyes.count < 3 else { return }

        let eye = AbyssEye(
            x: CGFloat.random(in: 40...(screenW - 40)),
            y: CGFloat.random(in: floatTop...(floatBottom - 40)),
            scale: CGFloat.random(in: 0.6...1.2),
            opacity: 0,
            pupilOffsetX: CGFloat.random(in: -2...2),
            pupilOffsetY: CGFloat.random(in: -1...1)
        )
        abyssEyes.append(eye)

        let eyeID = eye.id

        // 페이드인
        withAnimation(.easeIn(duration: 1.2)) {
            if let idx = abyssEyes.firstIndex(where: { $0.id == eyeID }) {
                abyssEyes[idx].opacity = Double.random(in: 0.3...0.7)
            }
        }

        // 동공 움직임
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            withAnimation(.easeInOut(duration: 1.0)) {
                if let idx = abyssEyes.firstIndex(where: { $0.id == eyeID }) {
                    abyssEyes[idx].pupilOffsetX = CGFloat.random(in: -3...3)
                    abyssEyes[idx].pupilOffsetY = CGFloat.random(in: -1.5...1.5)
                }
            }
        }

        // 2~4초 후 페이드아웃
        let lifetime = Double.random(in: 2.0...4.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) { [self] in
            withAnimation(.easeOut(duration: 0.8)) {
                if let idx = abyssEyes.firstIndex(where: { $0.id == eyeID }) {
                    abyssEyes[idx].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                abyssEyes.removeAll { $0.id == eyeID }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startTimer() {
        roundTimer?.invalidate()
        let rt = Timer(timeInterval: 0.1, repeats: true) { [self] _ in
            guard alive, phase == .playing else {
                roundTimer?.invalidate()
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
    // MARK: - 단어 탭
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func wordTapped(_ word: FloatingWord) {
        guard alive, phase == .playing else { return }
        guard let idx = floatingWords.firstIndex(where: { $0.id == word.id }) else { return }
        guard !floatingWords[idx].placed, !floatingWords[idx].absorbing else { return }

        let nextCorrect = currentSentence[slotWords.count]

        if word.text == nextCorrect {
            // ✅ 정답 — 흡수 애니메이션
            floatingWords[idx].absorbing = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // 슬롯에 추가
            slotWords.append(word.text)

            // 짧은 딜레이 후 placed 처리
            let wordID = word.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                if let i = floatingWords.firstIndex(where: { $0.id == wordID }) {
                    floatingWords[i].placed = true
                }
            }

            // 안개 잠시 밝아짐 (정답 피드백)
            let prevDensity = fogDensity
            withAnimation(.easeOut(duration: 0.3)) {
                fogDensity = max(0.05, fogDensity - 0.08)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                withAnimation(.easeIn(duration: 0.5)) {
                    fogDensity = prevDensity
                }
            }

            if slotWords.count >= currentSentence.count {
                roundCleared()
            }
        } else {
            // ❌ 오답 — 화면 흔들림 + 안개 폭발 + 저승사자
            floatingWords[idx].wrongFlash = true
            timeLeft = max(0, timeLeft - 1.5)

            // 흐름 방향으로 강하게 튕김
            let speed = baseWordSpeed(round) * 3.0
            let angle = flowAngle + CGFloat.random(in: -0.5...0.5)
            floatingWords[idx].vx = cos(angle) * speed
            floatingWords[idx].vy = sin(angle) * speed

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioEngine?.fireFailureBlast()

            // 화면 흔들림
            triggerScreenShake()

            // 안개 폭발 (밀도 급증 후 복귀)
            let prevFog = fogDensity
            fogDensity = min(0.8, fogDensity + 0.3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                withAnimation(.easeOut(duration: 0.8)) {
                    fogDensity = prevFog + 0.05  // 약간 더 짙어진 상태로 복귀
                }
            }

            // 저승사자 플래시
            showReaperFlash()

            let wordID = word.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                if let i = floatingWords.firstIndex(where: { $0.id == wordID }) {
                    floatingWords[i].wrongFlash = false
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 화면 흔들림
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func triggerScreenShake() {
        screenShakeTimer?.invalidate()
        var count = 0
        let maxCount = 8
        let st = Timer(timeInterval: 0.04, repeats: true) { [self] timer in
            count += 1
            if count >= maxCount {
                timer.invalidate()
                screenShakeX = 0
                screenShakeY = 0
                return
            }
            let intensity: CGFloat = 8.0 * CGFloat(maxCount - count) / CGFloat(maxCount)
            screenShakeX = CGFloat.random(in: -intensity...intensity)
            screenShakeY = CGFloat.random(in: -intensity * 0.6...intensity * 0.6)
        }
        RunLoop.main.add(st, forMode: .common)
        screenShakeTimer = st
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 저승사자 등장 (오답 시)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func showReaperFlash() {
        reaperVisible = true
        reaperOpacity = 0.85
        reaperScale = 1.6
        reaperShakeX = 0
        reaperShakeY = 0

        reaperShakeTimer?.invalidate()
        let rst = Timer(timeInterval: 0.04, repeats: true) { [self] _ in
            reaperShakeX = CGFloat.random(in: -20...20)
            reaperShakeY = CGFloat.random(in: -14...14)
        }
        RunLoop.main.add(rst, forMode: .common)
        reaperShakeTimer = rst

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            reaperShakeTimer?.invalidate()
            reaperShakeX = 0
            reaperShakeY = 0
            withAnimation(.easeOut(duration: 0.3)) {
                reaperOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [self] in
                reaperVisible = false
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 라운드 클리어 (성공 연출)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundCleared() {
        roundTimer?.invalidate()
        eyeSpawnTimer?.invalidate()
        phase = .success

        // ── 흐름 정지 ──
        flowFrozen = true
        flowSpeed = 0

        // 남은 단어 정지 (속도 0)
        for i in floatingWords.indices {
            floatingWords[i].vx = 0
            floatingWords[i].vy = 0
        }

        // ── 안개 소멸 ──
        fogClearing = true
        withAnimation(.easeOut(duration: 1.0)) {
            fogDensity = 0.02
            abyssDepth = 0
        }

        // ── 심연의 눈 사라짐 ──
        for eye in abyssEyes {
            let eyeID = eye.id
            withAnimation(.easeOut(duration: 0.5)) {
                if let idx = abyssEyes.firstIndex(where: { $0.id == eyeID }) {
                    abyssEyes[idx].opacity = 0
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            abyssEyes = []
        }

        // ── 성공 텍스트 ──
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            successScale = 1.0
            successOpacity = 1.0
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        round += 1

        if round >= totalRounds {
            // ── 최종 클리어 → 03 이미지 축하 연출 ──
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard alive else { return }
                showCelebration = true
                celebImgScale = 0.3
                celebImgOpacity = 0
                celebTextOpacity = 0
                celebGlow = 0

                withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.3)) {
                    celebImgScale = 1.05
                    celebImgOpacity = 1.0
                }

                withAnimation(.easeIn(duration: 1.0).delay(0.3)) {
                    celebGlow = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [self] in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        celebImgScale = 1.0
                    }
                }

                withAnimation(.easeIn(duration: 0.6).delay(0.8)) {
                    celebTextOpacity = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [self] in
                    withAnimation(
                        .easeInOut(duration: 2.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        celebImgScale = 1.08
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
                    guard alive else { return }
                    alive = false
                    onResult(.success)
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
                guard alive else { return }
                startRound()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 실패
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundFailed() {
        guard alive else { return }
        phase = .failed
        typingFocused = false
        // 타이핑 중이었으면 오디오 복원
        if isTypingRound { audioEngine?.resumeFromTyping() }
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        eyeSpawnTimer?.invalidate()

        audioEngine?.fireFailureBlast()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // 화면 강한 흔들림
        triggerScreenShake()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
        }

        round = max(0, round - 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            guard alive else { return }
            startRound()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 정리
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func cleanup() {
        alive = false
        typingFocused = false
        if isTypingRound { audioEngine?.resumeFromTyping() }
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        reaperShakeTimer?.invalidate()
        eyeSpawnTimer?.invalidate()
        screenShakeTimer?.invalidate()
    }
}
