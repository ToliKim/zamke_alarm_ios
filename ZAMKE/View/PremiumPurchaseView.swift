//
//  PremiumPurchaseView.swift
//  ZAMKE
//
//  화들짝 프리미엄 구매 화면
//

import SwiftUI

struct PremiumPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    var store: PremiumStore = .shared

    private let darkBg = Color(red: 0.02, green: 0.02, blue: 0.05)
    private let bloodRed = Color(red: 0.7, green: 0.08, blue: 0.08)
    private let warnRed = Color(red: 0.85, green: 0.12, blue: 0.12)

    @State private var glowPhase: Double = 0
    @State private var eyePulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 배경
            darkBg.ignoresSafeArea()

            // 붉은 비네트
            RadialGradient(
                colors: [
                    bloodRed.opacity(0.08),
                    bloodRed.opacity(0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 닫기 버튼
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // 아이콘
                ZStack {
                    Circle()
                        .fill(bloodRed.opacity(0.15))
                        .frame(width: 110, height: 110)
                        .scaleEffect(eyePulse)

                    Circle()
                        .fill(bloodRed.opacity(0.08))
                        .frame(width: 80, height: 80)

                    Image(systemName: "eye.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(warnRed)
                        .shadow(color: warnRed.opacity(0.6), radius: 12)
                }

                Spacer().frame(height: 28)

                // 제목
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow.opacity(0.9))
                    Text("화들짝 프리미엄")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white.opacity(0.95))
                }

                Spacer().frame(height: 12)

                Text("공포 미션으로 확실하게 깨어나세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                Spacer().frame(height: 32)

                // 기능 목록
                VStack(alignment: .leading, spacing: 14) {
                    featureRow("eye", "저승사자의 시선 — 눈을 밀어내라")
                    featureRow("hand.tap", "눈빛 연타 — 붉은 눈동자를 찍어라")
                    featureRow("text.cursor", "각성 문장 — 명언을 완성하라")
                    featureRow("bolt.fill", "수학 문제 — 긴장 속 두뇌 각성")
                    featureRow("infinity", "한 번 구매, 영구 사용")
                }
                .padding(.horizontal, 36)

                Spacer().frame(height: 40)

                // 가격 + 구매 버튼
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack(spacing: 8) {
                        if store.purchaseInProgress {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(store.displayPrice)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)

                            Text("으로 잠금 해제")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [warnRed, bloodRed],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: bloodRed.opacity(0.4), radius: 15, y: 5)
                }
                .disabled(store.purchaseInProgress)
                .padding(.horizontal, 28)

                Spacer().frame(height: 14)

                // 복원 버튼
                Button {
                    Task { await store.restore() }
                } label: {
                    Text("이전 구매 복원")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }

                // 에러 메시지
                if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.top, 8)
                }

                Spacer()

                // 하단 안내
                Text("한 번 결제로 영구 사용 · 구독 아님")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.2))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                eyePulse = 1.15
            }
        }
        .onChange(of: store.isPremiumUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(warnRed.opacity(0.8))
                .frame(width: 22)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
