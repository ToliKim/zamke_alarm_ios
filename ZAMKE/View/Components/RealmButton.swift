//
//  RealmButton.swift
//  ZAMKE
//
//  저승 세계의 인터페이스 오브젝트
//  5종 질감 버튼 + 커스텀 아이콘 + 3D 인터랙션
//

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. 커스텀 아이콘 (세계관)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct RealmIcon: View {
    let mode: AppMode
    let size: CGFloat

    var body: some View {
        Group {
            switch mode {
            case .hwadeuljjak: eyeIcon
            case .alarm:       brokenClockIcon
            case .timer:       timeTrailIcon
            case .report:      sealedScrollIcon
            case .settings:    gearworkIcon
            }
        }
        .frame(width: size, height: size)
    }

    // ── 화들짝: 빛나는 존재의 눈 ──
    private var eyeIcon: some View {
        ZStack {
            // 외부 눈꺼풀
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [Color.red.opacity(0.7), Color.red.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size * 0.85, height: size * 0.45)

            // 홍채
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.red.opacity(0.9),
                            Color(red: 0.6, green: 0.0, blue: 0.0),
                            Color(red: 0.2, green: 0.0, blue: 0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.17
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)

            // 동공
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.12, height: size * 0.12)

            // 하이라이트
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: size * 0.06, height: size * 0.06)
                .offset(x: -size * 0.04, y: -size * 0.04)

            // 눈 glow
            Ellipse()
                .fill(Color.red.opacity(0.15))
                .frame(width: size * 0.95, height: size * 0.55)
                .blur(radius: 6)
        }
    }

    // ── 알람: 깨진 시계 ──
    private var brokenClockIcon: some View {
        ZStack {
            // 시계 외곽 (금이 간)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.6).opacity(0.6),
                            Color(white: 0.3).opacity(0.4),
                            Color(white: 0.5).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
                .frame(width: size * 0.72, height: size * 0.72)

            // 균열선
            Path { p in
                p.move(to: CGPoint(x: size * 0.35, y: size * 0.18))
                p.addLine(to: CGPoint(x: size * 0.52, y: size * 0.42))
                p.addLine(to: CGPoint(x: size * 0.48, y: size * 0.55))
                p.addLine(to: CGPoint(x: size * 0.62, y: size * 0.78))
            }
            .stroke(Color(white: 0.5).opacity(0.5), lineWidth: 0.8)

            // 시침
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.5))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.28))
            }
            .stroke(Color(white: 0.7).opacity(0.7), lineWidth: 1.5)

            // 분침 (비틀어진)
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.5))
                p.addLine(to: CGPoint(x: size * 0.68, y: size * 0.38))
            }
            .stroke(Color(white: 0.5).opacity(0.5), lineWidth: 1.0)

            // 중심점
            Circle()
                .fill(Color(white: 0.6).opacity(0.6))
                .frame(width: 3, height: 3)
        }
    }

    // ── 타이머: 시간 잔상 ──
    private var timeTrailIcon: some View {
        ZStack {
            // 잔상 원들 (뒤에서 앞으로)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.08 + Double(i) * 0.06), lineWidth: 0.8)
                    .frame(
                        width: size * (0.7 - CGFloat(i) * 0.08),
                        height: size * (0.7 - CGFloat(i) * 0.08)
                    )
                    .offset(x: CGFloat(2 - i) * 3, y: CGFloat(2 - i) * 1.5)
            }

            // 메인 원
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.5)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size * 0.62, height: size * 0.62)

            // 모래시계 형상
            Path { p in
                let cx = size * 0.5
                let top = size * 0.28
                let mid = size * 0.5
                let bot = size * 0.72
                let w: CGFloat = size * 0.14

                p.move(to: CGPoint(x: cx - w, y: top))
                p.addLine(to: CGPoint(x: cx + w, y: top))
                p.addLine(to: CGPoint(x: cx + 1, y: mid))
                p.addLine(to: CGPoint(x: cx + w, y: bot))
                p.addLine(to: CGPoint(x: cx - w, y: bot))
                p.addLine(to: CGPoint(x: cx - 1, y: mid))
                p.closeSubpath()
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.8)

            // 내부 점
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 2.5, height: 2.5)
                .offset(y: size * 0.12)
        }
    }

    // ── 리포트: 봉인된 문서 ──
    private var sealedScrollIcon: some View {
        ZStack {
            // 두루마리 몸체
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.22).opacity(0.6),
                            Color(white: 0.14).opacity(0.5),
                            Color(white: 0.18).opacity(0.55)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.48, height: size * 0.65)

            // 글줄 (흐릿한 텍스트 라인)
            VStack(spacing: 3.5) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.white.opacity(0.08 + Double(i) * 0.01))
                        .frame(
                            width: size * (0.32 - CGFloat(i) * 0.02),
                            height: 1.2
                        )
                }
            }
            .offset(y: -size * 0.04)

            // 봉인 (빨간 원)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.5, green: 0.05, blue: 0.05),
                                Color(red: 0.3, green: 0.02, blue: 0.02)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.08
                        )
                    )
                    .frame(width: size * 0.18, height: size * 0.18)

                // 봉인 문양
                Path { p in
                    let cx = size * 0.5
                    let cy = size * 0.58
                    let r: CGFloat = size * 0.05
                    for i in 0..<4 {
                        let angle = Double(i) * .pi / 2
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(
                            x: cx + cos(angle) * r,
                            y: cy + sin(angle) * r
                        ))
                    }
                }
                .stroke(Color.red.opacity(0.5), lineWidth: 0.6)
            }
            .offset(y: size * 0.08)
        }
    }

    // ── 설정: 기계 장치 ──
    private var gearworkIcon: some View {
        ZStack {
            // 큰 톱니바퀴
            gearShape(teeth: 8, outerR: size * 0.33, innerR: size * 0.24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(white: 0.45).opacity(0.5),
                            Color(white: 0.25).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            // 중심 구멍
            Circle()
                .stroke(Color(white: 0.4).opacity(0.4), lineWidth: 1)
                .frame(width: size * 0.16, height: size * 0.16)

            // 작은 톱니바퀴 (오른쪽 위)
            gearShape(teeth: 6, outerR: size * 0.16, innerR: size * 0.11)
                .stroke(Color(white: 0.35).opacity(0.4), lineWidth: 0.8)
                .offset(x: size * 0.24, y: -size * 0.2)

            // 나사 볼트 표시
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(white: 0.3).opacity(0.3))
                    .frame(width: 2.5, height: 2.5)
                    .offset(
                        x: cos(Double(i) * 2.094) * size * 0.2,
                        y: sin(Double(i) * 2.094) * size * 0.2
                    )
            }
        }
    }

    private func gearShape(teeth: Int, outerR: CGFloat, innerR: CGFloat) -> Path {
        Path { p in
            let cx = size * 0.5
            let cy = size * 0.5
            let step = 2.0 * .pi / Double(teeth * 2)

            for i in 0..<(teeth * 2) {
                let angle = step * Double(i)
                let r = (i % 2 == 0) ? outerR : innerR
                let pt = CGPoint(
                    x: cx + cos(angle) * r,
                    y: cy + sin(angle) * r
                )
                if i == 0 { p.move(to: pt) }
                else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. 질감 배경 (5종)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct RealmButtonTexture: View {
    let mode: AppMode

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                switch mode {
                case .hwadeuljjak: obsidianTexture(w: w, h: h)
                case .alarm:       metalTexture(w: w, h: h)
                case .timer:       darkGlassTexture(w: w, h: h)
                case .report:      stoneTexture(w: w, h: h)
                case .settings:    steelPlateTexture(w: w, h: h)
                }
            }
        }
    }

    // ── 화들짝: 검은 유광 돌 + 균열 ──
    @ViewBuilder
    private func obsidianTexture(w: CGFloat, h: CGFloat) -> some View {
        // 기본 유광 돌
        LinearGradient(
            colors: [
                Color(white: 0.10),
                Color(white: 0.06),
                Color(white: 0.08),
                Color(white: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // 유광 반사
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.06), location: 0.0),
                .init(color: Color.clear, location: 0.3),
                .init(color: Color.clear, location: 0.7),
                .init(color: Color.white.opacity(0.02), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // 번개 균열
        Path { p in
            p.move(to: CGPoint(x: w * 0.15, y: h * 0.2))
            p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.35))
            p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.4))
            p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.65))
            p.addLine(to: CGPoint(x: w * 0.3, y: h * 0.68))
            p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.85))
        }
        .stroke(Color.red.opacity(0.18), lineWidth: 0.8)
        .shadow(color: .red.opacity(0.15), radius: 3)

        // 두 번째 균열
        Path { p in
            p.move(to: CGPoint(x: w * 0.7, y: h * 0.1))
            p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.3))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.45))
        }
        .stroke(Color.red.opacity(0.1), lineWidth: 0.5)
    }

    // ── 알람: 금속 + 스크래치 ──
    @ViewBuilder
    private func metalTexture(w: CGFloat, h: CGFloat) -> some View {
        // 브러시드 메탈
        LinearGradient(
            colors: [
                Color(white: 0.12),
                Color(white: 0.09),
                Color(white: 0.11),
                Color(white: 0.07),
                Color(white: 0.10)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        // 미세한 스크래치들
        ForEach(0..<6, id: \.self) { i in
            Path { p in
                let y = h * (0.15 + Double(i) * 0.14)
                p.move(to: CGPoint(x: w * 0.05, y: y))
                p.addLine(to: CGPoint(x: w * (0.4 + Double(i % 3) * 0.2), y: y + 2))
            }
            .stroke(Color.white.opacity(0.03), lineWidth: 0.3)
        }

        // 금속 하이라이트
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.04), location: 0.0),
                .init(color: Color.clear, location: 0.15),
                .init(color: Color.clear, location: 0.85),
                .init(color: Color.white.opacity(0.02), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // ── 타이머: 어두운 유리 + 내부 안개 ──
    @ViewBuilder
    private func darkGlassTexture(w: CGFloat, h: CGFloat) -> some View {
        // 어두운 유리
        Color(white: 0.07)

        // 안개 느낌
        RadialGradient(
            colors: [
                Color(white: 0.15, opacity: 0.15),
                Color(white: 0.10, opacity: 0.06),
                Color.clear
            ],
            center: UnitPoint(x: 0.3, y: 0.4),
            startRadius: 0,
            endRadius: w * 0.6
        )

        // 두 번째 안개 덩어리
        RadialGradient(
            colors: [
                Color(white: 0.12, opacity: 0.10),
                Color.clear
            ],
            center: UnitPoint(x: 0.75, y: 0.6),
            startRadius: 0,
            endRadius: w * 0.35
        )

        // 유리 반사
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.05), location: 0.0),
                .init(color: Color.white.opacity(0.01), location: 0.2),
                .init(color: Color.clear, location: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // ── 리포트: 묵직한 석재 ──
    @ViewBuilder
    private func stoneTexture(w: CGFloat, h: CGFloat) -> some View {
        // 석재 기본
        LinearGradient(
            colors: [
                Color(white: 0.10),
                Color(white: 0.08),
                Color(white: 0.09),
                Color(white: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        // 결 무늬
        ForEach(0..<4, id: \.self) { i in
            Path { p in
                let y = h * (0.2 + Double(i) * 0.2)
                p.move(to: CGPoint(x: 0, y: y))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: y + 6),
                    control: CGPoint(x: w * 0.5, y: y + CGFloat(i % 2 == 0 ? 8 : -4))
                )
            }
            .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
        }

        // 미세한 그레인
        RadialGradient(
            colors: [
                Color(white: 0.12, opacity: 0.08),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.3),
            startRadius: 0,
            endRadius: w * 0.5
        )
    }

    // ── 설정: 차가운 철판 ──
    @ViewBuilder
    private func steelPlateTexture(w: CGFloat, h: CGFloat) -> some View {
        // 철판 기본
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.10),
                Color(red: 0.04, green: 0.05, blue: 0.08),
                Color(red: 0.05, green: 0.06, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // 미세 격자
        Path { p in
            for i in stride(from: 0, through: w, by: w / 8) {
                p.move(to: CGPoint(x: i, y: 0))
                p.addLine(to: CGPoint(x: i, y: h))
            }
        }
        .stroke(Color.white.opacity(0.015), lineWidth: 0.3)

        // 냉기 하이라이트
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.3, green: 0.4, blue: 0.55).opacity(0.06), location: 0.0),
                .init(color: Color.clear, location: 0.3),
                .init(color: Color.clear, location: 0.8),
                .init(color: Color(red: 0.3, green: 0.4, blue: 0.55).opacity(0.03), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. 3D 카드 버튼 스타일
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct RealmButtonStyle: ButtonStyle {
    let mode: AppMode

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. RealmButton (완성형)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct RealmButton: View {
    let mode: AppMode
    let action: () -> Void

    @State private var flashOpacity: Double = 0
    @State private var glowPulse: Double = 0

    // glow 색상
    private var glowColor: Color {
        switch mode {
        case .hwadeuljjak: return .red
        case .alarm:       return Color(white: 0.6)
        case .timer:       return Color(red: 0.4, green: 0.5, blue: 0.7)
        case .report:      return Color(red: 0.5, green: 0.35, blue: 0.2)
        case .settings:    return Color(red: 0.35, green: 0.45, blue: 0.55)
        }
    }

    // 텍스트 색상 (탁한 흰색 계열)
    private var textColor: Color {
        switch mode {
        case .hwadeuljjak: return Color(red: 0.92, green: 0.85, blue: 0.82)
        case .alarm:       return Color(red: 0.88, green: 0.88, blue: 0.90)
        case .timer:       return Color(red: 0.82, green: 0.87, blue: 0.95)
        case .report:      return Color(red: 0.88, green: 0.82, blue: 0.75)
        case .settings:    return Color(red: 0.80, green: 0.85, blue: 0.90)
        }
    }

    var body: some View {
        Button(action: {
            triggerFlash()
            action()
        }) {
            ZStack {
                // ── 질감 배경 ──
                RealmButtonTexture(mode: mode)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // ── 3D 상단 하이라이트 ──
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 14)

                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // ── 3D 하단 그림자 (내부) ──
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.25),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // ── 빛 번쩍임 (터치 시) ──
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(flashOpacity * 0.5),
                                Color.white.opacity(flashOpacity * 0.15),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.4, y: 0.3),
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .allowsHitTesting(false)

                // ── glow 테두리 ──
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        glowColor.opacity(0.12 + glowPulse * 0.08),
                        lineWidth: 0.8
                    )
                    .shadow(color: glowColor.opacity(0.08 + glowPulse * 0.05), radius: 6)

                // ── 콘텐츠 ──
                HStack(spacing: 14) {
                    RealmIcon(mode: mode, size: 28)
                        .padding(.leading, 2)

                    Text(mode.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .tracking(3)
                        .foregroundColor(textColor.opacity(0.85))
                        .shadow(color: glowColor.opacity(0.2), radius: 4)

                    Spacer()

                    // 우측 미세 장식
                    RoundedRectangle(cornerRadius: 1)
                        .fill(glowColor.opacity(0.15))
                        .frame(width: 2, height: 14)
                        .padding(.trailing, 2)
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 52)
        }
        .buttonStyle(RealmButtonStyle(mode: mode))
        // ── 외부 3D 그림자 (떠있는 느낌) ──
        .shadow(color: Color.black.opacity(0.5), radius: 8, y: 5)
        .shadow(color: glowColor.opacity(0.06), radius: 12, y: 2)
        .onAppear {
            withAnimation(
                .easeInOut(duration: Double.random(in: 2.8...4.0))
                .repeatForever(autoreverses: true)
            ) {
                glowPulse = 1.0
            }
        }
    }

    private func triggerFlash() {
        flashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.3)) {
            flashOpacity = 0
        }
    }
}
