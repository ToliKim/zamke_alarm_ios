//
//  PatternMissionView.swift
//  ZAMKE
//
//  미션 2: 패턴 맞추기
//
//  3×3 네모 그리드 → 패턴 순서대로 빛남 → 유저가 같은 순서로 탭
//  5라운드 (패턴 길이: 3, 4, 4, 5, 5)
//  틀리면 한 라운드 되돌리기
//
//  ⚠️ 안정성 핵심:
//  - .task {} 로 시작 (onAppear보다 안정적)
//  - 패턴 표시를 Timer 1개로 구동 (asyncAfter 체인 제거)
//  - onDisappear에서 모든 타이머 정리
//

import SwiftUI
import AudioToolbox

struct PatternMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    enum Phase { case showing, input, success, failed }

    @State private var phase: Phase = .showing
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 5
    private let patternLengths = [3, 4, 4, 5, 5]

    // 패턴
    @State private var pattern: [Int] = []
    @State private var showIndex = 0
    @State private var inputIndex = 0
    @State private var litCell: Int? = nil
    @State private var wrongCell: Int? = nil
    @State private var correctCells: Set<Int> = []

    // 패턴 표시 타이머 (단일 Timer — asyncAfter 체인 대체)
    @State private var showTimer: Timer?
    @State private var showStep = 0        // 0=빛남, 1=꺼짐 교대
    @State private var gameStarted = false // 중복 시작 방지

    // 02.png
    @State private var reaperBlur: CGFloat = 8
    @State private var reaperOpacity: Double = 0.2

    var body: some View {
        ZStack {
            // 배경
            Image("02")
                .resizable()
                .scaledToFit()
                .blur(radius: reaperBlur)
                .opacity(reaperOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // 회차
                HStack(spacing: 6) {
                    ForEach(0..<totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i < round
                                  ? Color.green.opacity(0.7)
                                  : (i == round
                                     ? Color(red: 1.0, green: 0.23, blue: 0.23)
                                     : Color.white.opacity(0.12)))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 20)

                Spacer()

                // 상태 텍스트
                Text(phase == .showing ? "기억하라" : (phase == .input ? "입력하라" : ""))
                    .font(Font.system(size: 24, weight: .black).width(.condensed))
                    .foregroundColor(phase == .showing
                        ? Color(red: 1.0, green: 0.23, blue: 0.23)
                        : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .padding(.bottom, 16)

                // 3×3 그리드
                gridView
                    .padding(.horizontal, 40)

                Spacer()

                // 진행 표시
                if phase == .input {
                    HStack(spacing: 4) {
                        ForEach(0..<pattern.count, id: \.self) { i in
                            Circle()
                                .fill(i < inputIndex
                                      ? Color.green.opacity(0.7)
                                      : Color.white.opacity(0.12))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 30)
                }

                Spacer().frame(height: 40)
            }

            // 실패
            if phase == .failed {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                Text("틀렸다")
                    .font(Font.system(size: 48, weight: .black).width(.condensed))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.6), radius: 30)
            }
        }
        // ⚠️ .task는 .onAppear보다 안정적 — .id() 변경 시에도 확실히 호출됨
        .task {
            guard !gameStarted else { return }
            gameStarted = true
            startGame()
        }
        .onDisappear { cleanup() }
    }

    // MARK: - 그리드

    private var gridView: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { col in
                        let idx = row * 3 + col
                        cellView(index: idx)
                    }
                }
            }
        }
    }

    private func cellView(index: Int) -> some View {
        let isLit = litCell == index
        let isWrong = wrongCell == index
        let isCorrect = correctCells.contains(index)

        return RoundedRectangle(cornerRadius: 10)
            .fill(cellColor(isLit: isLit, isWrong: isWrong, isCorrect: isCorrect))
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cellBorder(isLit: isLit, isWrong: isWrong, isCorrect: isCorrect), lineWidth: 2)
            )
            .shadow(
                color: isLit ? Color.red.opacity(0.5) :
                       (isCorrect ? Color.green.opacity(0.4) : .clear),
                radius: isLit || isCorrect ? 12 : 0
            )
            .onTapGesture {
                handleTap(index: index)
            }
    }

    private func cellColor(isLit: Bool, isWrong: Bool, isCorrect: Bool) -> Color {
        if isWrong { return Color(red: 0.8, green: 0.1, blue: 0.1) }
        if isLit { return Color(red: 0.7, green: 0.15, blue: 0.15) }
        if isCorrect { return Color(red: 0.1, green: 0.5, blue: 0.15) }
        return Color.white.opacity(0.06)
    }

    private func cellBorder(isLit: Bool, isWrong: Bool, isCorrect: Bool) -> Color {
        if isWrong { return Color.red.opacity(0.8) }
        if isLit { return Color.red.opacity(0.6) }
        if isCorrect { return Color.green.opacity(0.5) }
        return Color.white.opacity(0.08)
    }

    // MARK: - 게임

    private func startGame() {
        alive = true
        round = 0
        startRound()
    }

    private func startRound() {
        guard alive, round < totalRounds else { return }
        showTimer?.invalidate()
        phase = .showing
        inputIndex = 0
        litCell = nil
        wrongCell = nil
        correctCells = []

        // 패턴 생성
        let length = patternLengths[round]
        var p: [Int] = []
        for _ in 0..<length {
            var next = Int.random(in: 0...8)
            while next == p.last {
                next = Int.random(in: 0...8)
            }
            p.append(next)
        }
        pattern = p

        // 02.png 반응
        let newBlur = 8.0 - Double(round) * 1.2
        withAnimation(.easeOut(duration: 0.3)) {
            reaperBlur = CGFloat(max(2, newBlur))
            reaperOpacity = 0.2 + Double(round) * 0.1
        }

        // ⚠️ Timer 기반 패턴 표시 (asyncAfter 체인 대신)
        showIndex = 0
        showStep = 0
        startShowTimer()
    }

    // MARK: - 패턴 표시 (단일 Timer)

    private func startShowTimer() {
        showTimer?.invalidate()

        // 0.5초 빛남 → 0.15초 꺼짐 교대
        // showStep 0 = 빛남 시작, showStep 1 = 꺼짐
        let st = Timer(timeInterval: 0.08, repeats: true) { [self] _ in
            guard alive, phase == .showing else {
                showTimer?.invalidate()
                return
            }

            if showStep == 0 {
                // 빛남 시작
                if showIndex < pattern.count {
                    litCell = pattern[showIndex]
                    AudioServicesPlaySystemSound(1322)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showStep = 1
                } else {
                    // 패턴 다 보여줌 → 입력 페이즈
                    showTimer?.invalidate()
                    litCell = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                        guard alive else { return }
                        phase = .input
                    }
                }
            } else if showStep < 7 {
                // 빛남 유지 (0.08 * 6 ≈ 0.48초)
                showStep += 1
            } else if showStep == 7 {
                // 꺼짐
                litCell = nil
                showStep += 1
            } else if showStep < 10 {
                // 꺼짐 유지 (0.08 * 2 ≈ 0.16초)
                showStep += 1
            } else {
                // 다음 셀로
                showIndex += 1
                showStep = 0
            }
        }
        RunLoop.main.add(st, forMode: .common)
        showTimer = st
    }

    // MARK: - 입력

    private func handleTap(index: Int) {
        guard alive, phase == .input else { return }

        if pattern[inputIndex] == index {
            // 정답
            correctCells.insert(index)
            AudioServicesPlaySystemSound(1057)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            inputIndex += 1

            // 초록 플래시 제거
            let tappedIdx = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                correctCells.remove(tappedIdx)
            }

            if inputIndex >= pattern.count {
                roundCleared()
            }
        } else {
            // 오답
            wrongCell = index
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            missionFailed()
        }
    }

    // MARK: - 라운드 클리어

    private func roundCleared() {
        round += 1

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if round >= totalRounds {
            missionCleared()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                guard alive else { return }
                startRound()
            }
        }
    }

    // MARK: - 미션 클리어

    private func missionCleared() {
        guard alive else { return }
        alive = false
        phase = .success
        showTimer?.invalidate()

        withAnimation(.easeOut(duration: 0.8)) {
            reaperBlur = 15
            reaperOpacity = 0
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            onResult(.success)
        }
    }

    // MARK: - 실패 (한 라운드만 되돌리기)

    private func missionFailed() {
        guard alive else { return }
        phase = .failed
        showTimer?.invalidate()

        withAnimation(.easeIn(duration: 0.1)) {
            reaperBlur = 0
            reaperOpacity = 0.7
        }

        // 1차 — 랜덤 실패 폭풍 (아쟁/경고음/Bell/Chicken/Forest/Puppy 중 랜덤)
        audioEngine?.fireFailureBlast()
        AudioServicesPlaySystemSound(1322)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 한 라운드 되돌리기
        round = max(0, round - 1)

        // 2차 — 0.5초 후 또 다른 랜덤 조합
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            guard alive else { return }
            audioEngine?.fireFailureBlast()
        }

        // 1.2초 후 재시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
            guard alive else { return }
            wrongCell = nil
            withAnimation(.easeOut(duration: 0.3)) {
                reaperBlur = 8.0 - Double(round) * 1.2
                reaperOpacity = 0.2 + Double(round) * 0.1
            }
            startRound()
        }
    }

    // MARK: - 정리

    private func cleanup() {
        alive = false
        showTimer?.invalidate()
        showTimer = nil
    }
}
