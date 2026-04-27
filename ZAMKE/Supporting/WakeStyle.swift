//
//  WakeStyle.swift
//  ZAMKE
//
//  깨우는 사운드 선택
//

import SwiftUI
import AVFoundation

// MARK: - 카테고리

enum WakeCategory: String, Codable, CaseIterable, Identifiable {
    case basic        = "basic"
    case hwadeuljjak  = "hwadeuljjak"
    case animal       = "animal"

    var id: String { rawValue }

    static var displayOrder: [WakeCategory] {
        [.basic, .hwadeuljjak, .animal]
    }

    var title: String {
        switch self {
        case .basic:        return "기본 알람"
        case .hwadeuljjak:  return "화들짝 공포"
        case .animal:       return "동물소리"
        }
    }

    var icon: String {
        switch self {
        case .basic:        return "bell.fill"
        case .hwadeuljjak:  return "eye.fill"
        case .animal:       return "pawprint.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .basic:        return .orange
        case .hwadeuljjak:  return Color(red: 0.85, green: 0.12, blue: 0.12)
        case .animal:       return .green
        }
    }

    /// 미리듣기 가능 여부 (화들짝 공포 제외)
    var canPreview: Bool {
        self != .hwadeuljjak
    }

    var sounds: [WakeSound] {
        switch self {
        case .basic:
            return [
                WakeSound(id: "bell1", name: "벨 1", emoji: "🔔", systemSound: "Bell_b1", previewFile: ("Bell", "b1")),
                WakeSound(id: "bell2", name: "벨 2", emoji: "🔔", systemSound: "Bell_b2", previewFile: ("Bell", "b2")),
                WakeSound(id: "bell3", name: "벨 3", emoji: "🔔", systemSound: "Bell_b3", previewFile: ("Bell", "b3")),
                WakeSound(id: "bell4", name: "벨 4", emoji: "🔔", systemSound: "Bell_b4", previewFile: ("Bell", "b4")),
                WakeSound(id: "bell5", name: "벨 5", emoji: "🔔", systemSound: "Bell_b5", previewFile: ("Bell", "b5")),
                WakeSound(id: "bell6", name: "벨 6", emoji: "🔔", systemSound: "Bell_b6", previewFile: ("Bell", "b6")),
            ]
        case .hwadeuljjak:
            return [
                WakeSound(id: "hw_default", name: "화들짝", emoji: "💀", systemSound: "HwRandom", intensity: .random),
            ]
        case .animal:
            return [
                WakeSound(id: "chicken", name: "닭",     emoji: "🐓", systemSound: "Chicken_c1", previewFile: ("Chicken", "c1")),
                WakeSound(id: "bird",    name: "새",     emoji: "🐦", systemSound: "Forest_f",   previewFile: ("Forest", "f")),
                WakeSound(id: "puppy",   name: "강아지", emoji: "🐕", systemSound: "Puppy_p",    previewFile: ("Puppy", "p")),
            ]
        }
    }
}

// MARK: - 화들짝 강도

enum HwadeuljjakIntensity: String, Codable {
    case light  = "light"
    case medium = "medium"
    case random = "random"
}

// MARK: - 개별 사운드

struct WakeSound: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var emoji: String = ""
    var desc: String = ""
    let systemSound: String
    var intensity: HwadeuljjakIntensity? = nil

    /// 미리듣기 파일 (folder, filename without extension)
    var previewFile: (folder: String, name: String)? = nil

    // Codable — previewFile 튜플은 커스텀 처리
    enum CodingKeys: String, CodingKey {
        case id, name, emoji, desc, systemSound, intensity
        case previewFolder, previewName
    }

    init(id: String, name: String, emoji: String = "", desc: String = "",
         systemSound: String, intensity: HwadeuljjakIntensity? = nil,
         previewFile: (String, String)? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.desc = desc
        self.systemSound = systemSound
        self.intensity = intensity
        self.previewFile = previewFile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        desc = try c.decodeIfPresent(String.self, forKey: .desc) ?? ""
        systemSound = try c.decode(String.self, forKey: .systemSound)
        intensity = try c.decodeIfPresent(HwadeuljjakIntensity.self, forKey: .intensity)
        if let folder = try c.decodeIfPresent(String.self, forKey: .previewFolder),
           let pname = try c.decodeIfPresent(String.self, forKey: .previewName) {
            previewFile = (folder, pname)
        } else {
            previewFile = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(desc, forKey: .desc)
        try c.encode(systemSound, forKey: .systemSound)
        try c.encodeIfPresent(intensity, forKey: .intensity)
        try c.encodeIfPresent(previewFile?.folder, forKey: .previewFolder)
        try c.encodeIfPresent(previewFile?.name, forKey: .previewName)
    }

    static func == (lhs: WakeSound, rhs: WakeSound) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 선택 상태

struct WakeStyleSelection: Codable, Equatable {
    var category: WakeCategory
    var soundId: String

    static let defaultSelection = WakeStyleSelection(
        category: .basic,
        soundId: "bell1"
    )

    var sound: WakeSound? {
        category.sounds.first { $0.id == soundId }
    }

    var displayName: String {
        if category == .hwadeuljjak {
            return "화들짝"
        }
        return sound?.name ?? category.title
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 미리듣기 매니저
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@MainActor @Observable
final class SoundPreviewManager {
    var playingId: String? = nil
    private var player: AVAudioPlayer?

    func toggle(_ sound: WakeSound) {
        // 같은 사운드 → 정지
        if playingId == sound.id {
            stop()
            return
        }

        stop()

        guard let (folder, name) = sound.previewFile else { return }

        // 번들에서 오디오 파일 찾기
        let url: URL? = {
            if let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/\(folder)") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: folder) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: "wav") { return u }
            // 전체 번들 탐색
            if let bp = Bundle.main.resourcePath,
               let en = FileManager.default.enumerator(atPath: bp) {
                while let p = en.nextObject() as? String {
                    if p.hasSuffix("/\(name).wav") || p == "\(name).wav" {
                        return URL(fileURLWithPath: bp).appendingPathComponent(p)
                    }
                }
            }
            return nil
        }()

        guard let fileURL = url else {
            #if DEBUG
            print("⚠️ 미리듣기 파일 없음: \(folder)/\(name).wav")
            #endif
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.volume = 0.7
            player?.numberOfLoops = 0
            player?.play()
            playingId = sound.id

            // 재생 종료 후 상태 리셋
            let duration = player?.duration ?? 3.0
            let soundId = sound.id
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.1) * 1_000_000_000))
                if self?.playingId == soundId {
                    self?.playingId = nil
                }
            }
        } catch {
            #if DEBUG
            print("❌ 미리듣기 실패: \(error)")
            #endif
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingId = nil
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 선택 뷰
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct WakeStylePickerView: View {
    @Binding var selection: WakeStyleSelection
    @Environment(\.dismiss) private var dismiss
    @State private var previewManager = SoundPreviewManager()

    private let bg = Color(red: 0.035, green: 0.05, blue: 0.09)
    private let cardBg = Color(red: 0.065, green: 0.085, blue: 0.14)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 4) {
                headerView

                ForEach(Array(WakeCategory.displayOrder.enumerated()), id: \.element.id) { idx, cat in
                    if cat == .hwadeuljjak {
                        HwadeuljjakCard(selection: $selection)
                    } else {
                        normalCategoryCard(cat)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onDisappear {
            previewManager.stop()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 0) {
            Button {
                previewManager.stop()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("돌아가기")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.55))
            }
            .frame(width: 90, alignment: .leading)

            Spacer()

            Text("깨우는 사운드")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.92))

            Spacer()

            Color.clear.frame(width: 90, height: 1)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 2)
    }

    // MARK: - Normal Category Card

    private func normalCategoryCard(_ category: WakeCategory) -> some View {
        let catSelected = selection.category == category

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(category.iconColor.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: category.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(category.iconColor)
                }

                Text(category.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(category.sounds) { sound in
                    normalSoundRow(sound: sound, category: category)
                }
            }
            .padding(.bottom, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    catSelected ? category.iconColor.opacity(0.35) : Color.white.opacity(0.04),
                    lineWidth: catSelected ? 1.2 : 0.5
                )
        )
    }

    // MARK: - Normal Sound Row (미리듣기 스피커 포함)

    private func normalSoundRow(sound: WakeSound, category: WakeCategory) -> some View {
        let isSelected = selection.category == category && selection.soundId == sound.id
        let isPlaying = previewManager.playingId == sound.id

        return HStack(spacing: 0) {
            // 선택 버튼 (사운드 이름 + 라디오)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = WakeStyleSelection(category: category, soundId: sound.id)
                }
            } label: {
                HStack(spacing: 10) {
                    Text(sound.emoji)
                        .font(.system(size: 18))
                        .frame(width: 26, height: 26)

                    Text(sound.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))

                    Spacer()

                    // 라디오 인디케이터
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? category.iconColor : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1.5
                            )
                            .frame(width: 18, height: 18)

                        if isSelected {
                            Circle()
                                .fill(category.iconColor)
                                .frame(width: 9, height: 9)
                        }
                    }
                }
            }

            // 미리듣기 버튼
            if category.canPreview && sound.previewFile != nil {
                Button {
                    previewManager.toggle(sound)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPlaying ? category.iconColor.opacity(0.18) : Color.white.opacity(0.04))
                            .frame(width: 32, height: 32)

                        Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                            .font(.system(size: isPlaying ? 10 : 11))
                            .foregroundColor(isPlaying ? category.iconColor : .white.opacity(0.4))
                            .symbolEffect(.pulse, isActive: isPlaying)
                    }
                }
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? category.iconColor.opacity(0.08) : Color.clear)
                .padding(.horizontal, 4)
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 화들짝 공포 카드 (독립 컴포넌트)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct HwadeuljjakCard: View {
    @Binding var selection: WakeStyleSelection
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var showPurchase = false

    private var store: PremiumStore { .shared }
    private let category: WakeCategory = .hwadeuljjak

    // 색상 팔레트 — 절제된 공포
    private let darkBase   = Color(red: 0.043, green: 0.05, blue: 0.10)
    private let deepBlack  = Color(red: 0.02, green: 0.02, blue: 0.05)
    private let bloodRed   = Color(red: 0.7, green: 0.08, blue: 0.08)
    private let warnRed    = Color(red: 0.85, green: 0.12, blue: 0.12)
    private let dimRed     = Color(red: 0.35, green: 0.06, blue: 0.06)

    private var isActive: Bool {
        selection.category == .hwadeuljjak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hwHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // 공포 설명 텍스트
            Text("공포 미션 3단계를 깨야 알람이 꺼집니다")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(hwBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(hwBorder)
        .shadow(color: bloodRed.opacity(isActive ? 0.18 : 0.06), radius: isActive ? 14 : 8, y: 4)
        .onAppear { startAmbientPulse() }
        .sheet(isPresented: $showPurchase) {
            PremiumPurchaseView()
        }
    }

    private var hwBackground: some View {
        ZStack {
            LinearGradient(
                colors: [darkBase, deepBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [bloodRed.opacity(0.12 * glowOpacity), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 280
            )
            RadialGradient(
                colors: [bloodRed.opacity(0.06 * glowOpacity), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 200
            )
        }
    }

    private var hwBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [
                        bloodRed.opacity(isActive ? 0.5 : 0.25),
                        dimRed.opacity(isActive ? 0.3 : 0.12),
                        bloodRed.opacity(isActive ? 0.4 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isActive ? 1.2 : 0.8
            )
            .shadow(color: bloodRed.opacity(isActive ? 0.15 : 0.05), radius: 6)
    }

    private var hwHeader: some View {
        Button {
            if store.isPremiumUnlocked {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = WakeStyleSelection(category: .hwadeuljjak, soundId: "hw_default")
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                showPurchase = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(bloodRed.opacity(0.2))
                        .frame(width: 26, height: 26)
                        .blur(radius: 4)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(bloodRed.opacity(0.2))
                        .frame(width: 22, height: 22)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(warnRed)
                        .rotationEffect(.degrees(-8))
                        .shadow(color: warnRed.opacity(0.6), radius: 3)
                }
                .frame(width: 22, height: 22)

                Text("화들짝")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white.opacity(0.95))

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: store.isPremiumUnlocked ? "checkmark.seal.fill" : "crown.fill")
                        .font(.system(size: 8))
                    Text(store.isPremiumUnlocked ? "잠금 해제됨" : store.displayPrice)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundColor(store.isPremiumUnlocked
                    ? .green.opacity(0.9) : .yellow.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(store.isPremiumUnlocked
                            ? Color.green.opacity(0.10) : Color.yellow.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(store.isPremiumUnlocked
                            ? Color.green.opacity(0.25) : Color.yellow.opacity(0.25),
                                lineWidth: 0.5)
                )
                .shadow(color: store.isPremiumUnlocked
                    ? .green.opacity(0.1) : .yellow.opacity(0.1), radius: 4)

                // 선택 인디케이터
                hwIndicator(isSelected: isActive)
            }
        }
    }

    private func hwIndicator(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(warnRed.opacity(0.15))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseScale)
            }
            Circle()
                .stroke(
                    isSelected ? warnRed : Color.white.opacity(0.1),
                    lineWidth: isSelected ? 2 : 1.5
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(warnRed)
                    .frame(width: 12, height: 12)
                    .shadow(color: warnRed.opacity(0.5), radius: 3)
            }
        }
    }

    private func startAmbientPulse() {
        withAnimation(
            .easeInOut(duration: 0.9)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.35
        }
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 1.0
        }
    }
}
