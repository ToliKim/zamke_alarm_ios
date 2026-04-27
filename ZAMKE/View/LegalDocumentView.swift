//
//  LegalDocumentView.swift
//  ZAMKE
//
//  이용약관 / 개인정보 처리방침 표시 뷰
//

import SwiftUI

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.059, blue: 0.102)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.08))

                ScrollView {
                    Text(content)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(6)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                }
            }
        }
    }
}
