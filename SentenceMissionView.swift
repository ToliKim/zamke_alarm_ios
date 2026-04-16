//
//  SentenceMissionView.swift
//  ZAMKE
//
//  미션 3: 문장 완성 — "각성"
//
//  단어 블럭이 화면 위를 떠다닌다.
//  하단에 가로 슬롯이 나열되어 있다.
//  떠다니는 단어를 터치하면 → 다음 빈 슬롯으로 들어간다.
//  순서가 맞으면 안착, 틀리면 빨갛게 튕겨나감 + 시간 감소.
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
}

struct SentenceMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?

    // ── 페이즈 ──
    enum Phase { case ready, playing, success, failed }

    @State private var phase: Phase = .ready
    @State private var alive = true
    @State private var round = 0
    private let totalRounds = 5

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

    // ── 저승사자 등장 (오답 시) ──
    @State private var reaperVisible: Bool = false
    @State private var reaperShakeX: CGFloat = 0
    @State private var reaperShakeY: CGFloat = 0
    @State private var reaperOpacity: Double = 0
    @State private var reaperScale: CGFloat = 1.6
    @State private var reaperShakeTimer: Timer?

    // ── 함정 단어 풀 ──
    private let decoyPool: [String] = [
        "아마", "그래서", "하지만", "갑자기", "절대로",
        "어쩌면", "당연히", "분명", "사실", "결국",
        "그냥", "이미", "아직", "혹시", "바로",
        "거의", "좀", "매우", "꽤", "딱",
        "언제나", "가끔", "늘", "자주", "다시",
    ]

    // ── 화면 ──
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var gameStarted = false

    // 하단 슬롯 높이
    private let slotBarHeight: CGFloat = 70

    // 단어 떠다니는 영역
    private var floatTop: CGFloat { 80 }
    private var floatBottom: CGFloat { screenH - slotBarHeight - 90 }

    // ── 라운드별 제한시간 ──
    private func timeLimitForRound(_ r: Int) -> Double {
        switch r {
        case 0: return 18.0
        case 1: return 16.0
        case 2: return 14.0
        case 3: return 12.0
        default: return 10.0
        }
    }

    // ── 라운드별 단어 속도 ──
    private func wordSpeed(_ r: Int) -> CGFloat {
        switch r {
        case 0: return 1.2
        case 1: return 1.6
        case 2: return 2.0
        case 3: return 2.4
        default: return 2.8
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 문장 풀
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private let sentences: [[String]] = [
        ["나는", "오늘", "반드시", "성공한다"],
        ["지금", "이", "순간", "시작한다"],
        ["나는", "끝까지", "해낸다"],
        ["오늘은", "내가", "이긴다"],
        ["나는", "이미", "해내고", "있다"],
        ["멈추지", "않고", "계속", "간다"],
        ["나는", "나를", "이겨낸다"],
        ["오늘", "나는", "달라진다"],
        ["지금", "나는", "성장", "중이다"],
        ["나는", "더", "강해지고", "있다"],
        ["오늘", "반드시", "해내고", "만다"],
        ["나는", "절대", "포기하지", "않는다"],
        ["지금부터", "모든", "게", "달라진다"],
        ["나는", "오늘을", "장악한다"],
        ["나는", "스스로", "증명한다"],
        ["오늘", "나는", "한계를", "넘는다"],
        ["나는", "이미", "시작했다"],
        ["지금이", "바로", "기회다"],
        ["나는", "나를", "믿는다"],
        ["오늘", "나는", "움직인다"],
        ["나는", "반드시", "달성한다"],
        ["오늘", "나는", "끝까지", "간다"],
        ["나는", "오늘", "승리한다"],
        ["지금", "이", "순간", "집중한다"],
        ["나는", "더", "나아지고", "있다"],
        ["나는", "오늘", "변화를", "만든다"],
        ["나는", "끝까지", "버틴다"],
        ["오늘", "나는", "포기하지", "않는다"],
        ["나는", "계속", "전진한다"],
        ["지금", "나는", "실행한다"],
        ["나는", "오늘을", "바꾼다"],
        ["오늘", "나는", "행동한다"],
        ["나는", "나를", "초월한다"],
        ["나는", "끝까지", "살아남는다"],
        ["나는", "오늘", "집중한다"],
        ["지금", "나는", "도전한다"],
        ["나는", "나를", "단련한다"],
        ["오늘", "나는", "성장한다"],
        ["나는", "계속", "나아간다"],
        ["나는", "오늘", "해낸다"],
        ["나는", "반드시", "도달한다"],
        ["오늘", "나는", "실행한다"],
        ["나는", "멈추지", "않는다"],
        ["나는", "지금", "시작한다"],
        ["나는", "오늘", "완성한다"],
        ["나는", "계속", "도전한다"],
        ["오늘", "나는", "이겨낸다"],
        ["나는", "반드시", "이룬다"],
        ["나는", "끝까지", "간다"],
    ]

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        GeometryReader { geo in
            let _ = renderTick  // 리렌더 트리거

            ZStack {
                Color.black.ignoresSafeArea()

                // ── 레이어 1: 상단 UI (터치 통과) ──
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
                .allowsHitTesting(false)  // ← 터치 통과!

                // ── 레이어 2: 떠다니는 단어들 (터치 가능!) ──
                if phase == .playing {
                    ForEach(floatingWords) { word in
                        if !word.placed {
                            wordBubble(word)
                                .position(x: word.x, y: word.y)
                                .onTapGesture { wordTapped(word) }
                        }
                    }
                }

                // ── 레이어 3: 하단 슬롯 (고정) ──
                if phase == .playing || phase == .success {
                    VStack {
                        Spacer()
                        slotBar
                            .padding(.bottom, 50)
                    }
                    .allowsHitTesting(false)
                }

                // ── 레이어 4: 저승사자 등장 (오답 시) ──
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

                        // 붉은 플래시 오버레이
                        Color.red.opacity(reaperOpacity * 0.25)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // ── 레이어 5: 성공/실패/대기 텍스트 ──
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
            }
            .task {
                screenW = geo.size.width
                screenH = geo.size.height
                guard !gameStarted else { return }
                gameStarted = true
                startGame()
            }
            .onDisappear { cleanup() }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 떠다니는 단어 버블
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func wordBubble(_ word: FloatingWord) -> some View {
        Text(word.text)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(word.wrongFlash ? .red : .white.opacity(0.95))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(word.wrongFlash
                          ? Color.red.opacity(0.3)
                          : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(word.wrongFlash
                            ? Color.red.opacity(0.7)
                            : Color.white.opacity(0.25),
                            lineWidth: 1.5)
            )
            .shadow(color: word.wrongFlash
                    ? .red.opacity(0.5) : .white.opacity(0.06),
                    radius: word.wrongFlash ? 14 : 5)
            .contentShape(Rectangle())  // ← 터치 영역 확대
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 하단 슬롯 바 (가로)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var slotBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<currentSentence.count, id: \.self) { i in
                if i < slotWords.count {
                    // ✅ 채워진 슬롯
                    Text(slotWords[i])
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(phase == .success ? 0.5 : 0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.5), lineWidth: 1)
                        )
                } else if i == slotWords.count {
                    // 다음 빈 슬롯 (활성)
                    Text("?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.4),
                                        style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        )
                } else {
                    // 미래 슬롯
                    Text("?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.08))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1),
                                        style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
        phase = .ready
        slotWords = []
        floatingWords = []
        successScale = 0.8
        successOpacity = 0

        currentSentence = sentences.randomElement()!

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            guard alive else { return }
            spawnFloatingWords()
            phase = .playing
            timeLimit = timeLimitForRound(round)
            timeLeft = timeLimit
            startTimer()
            startWordMovement()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 단어 스폰
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func spawnFloatingWords() {
        let speed = wordSpeed(round)
        let margin: CGFloat = 50
        let top = floatTop + 20
        let bot = floatBottom - 20

        var words: [FloatingWord] = []

        // ── 정답 단어들 ──
        let shuffled = currentSentence.shuffled()
        for text in shuffled {
            let x = CGFloat.random(in: margin...(screenW - margin))
            let y = CGFloat.random(in: top...bot)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed
            words.append(FloatingWord(text: text, x: x, y: y, vx: vx, vy: vy))
        }

        // ── 함정 단어 2개 추가 (문장에 없는 단어) ──
        let sentenceSet = Set(currentSentence)
        let available = decoyPool.filter { !sentenceSet.contains($0) }
        let decoys = Array(available.shuffled().prefix(2))
        for text in decoys {
            let x = CGFloat.random(in: margin...(screenW - margin))
            let y = CGFloat.random(in: top...bot)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let vx = cos(angle) * speed * 1.1  // 함정은 약간 빠르게
            let vy = sin(angle) * speed * 1.1
            words.append(FloatingWord(text: text, x: x, y: y, vx: vx, vy: vy))
        }

        floatingWords = words.shuffled()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 단어 이동 타이머
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startWordMovement() {
        moveTimer?.invalidate()
        let mt = Timer(timeInterval: 0.033, repeats: true) { [self] _ in
            guard alive, phase == .playing else {
                moveTimer?.invalidate()
                return
            }
            moveWords()
            renderTick &+= 1
        }
        RunLoop.main.add(mt, forMode: .common)
        moveTimer = mt
    }

    private func moveWords() {
        let margin: CGFloat = 40
        let top = floatTop
        let bot = floatBottom

        for i in floatingWords.indices {
            guard !floatingWords[i].placed else { continue }

            floatingWords[i].x += floatingWords[i].vx
            floatingWords[i].y += floatingWords[i].vy

            // 벽 바운스
            if floatingWords[i].x < margin {
                floatingWords[i].x = margin
                floatingWords[i].vx = abs(floatingWords[i].vx)
            }
            if floatingWords[i].x > screenW - margin {
                floatingWords[i].x = screenW - margin
                floatingWords[i].vx = -abs(floatingWords[i].vx)
            }
            if floatingWords[i].y < top {
                floatingWords[i].y = top
                floatingWords[i].vy = abs(floatingWords[i].vy)
            }
            if floatingWords[i].y > bot {
                floatingWords[i].y = bot
                floatingWords[i].vy = -abs(floatingWords[i].vy)
            }

            // 미세 변동
            floatingWords[i].vx += CGFloat.random(in: -0.05...0.05)
            floatingWords[i].vy += CGFloat.random(in: -0.05...0.05)

            // 속도 제한
            let maxSpd = wordSpeed(round) * 1.5
            let spd = sqrt(floatingWords[i].vx * floatingWords[i].vx + floatingWords[i].vy * floatingWords[i].vy)
            if spd > maxSpd {
                floatingWords[i].vx = floatingWords[i].vx / spd * maxSpd
                floatingWords[i].vy = floatingWords[i].vy / spd * maxSpd
            }
            if spd < wordSpeed(round) * 0.5 {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                floatingWords[i].vx += cos(angle) * 0.3
                floatingWords[i].vy += sin(angle) * 0.3
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
        guard !floatingWords[idx].placed else { return }

        let nextCorrect = currentSentence[slotWords.count]

        if word.text == nextCorrect {
            // ✅ 정답
            floatingWords[idx].placed = true
            slotWords.append(word.text)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if slotWords.count >= currentSentence.count {
                roundCleared()
            }
        } else {
            // ❌ 오답 — 저승사자 등장 + 흔들림
            floatingWords[idx].wrongFlash = true
            timeLeft = max(0, timeLeft - 1.5)

            let speed = wordSpeed(round) * 2.5
            let angle = CGFloat.random(in: 0...(2 * .pi))
            floatingWords[idx].vx = cos(angle) * speed
            floatingWords[idx].vy = sin(angle) * speed

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audioEngine?.fireFailureBlast()

            // ━━ 붉은 저승사자 등장 ━━
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
    // MARK: - 저승사자 등장 (오답 시)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func showReaperFlash() {
        // 즉시 등장
        reaperVisible = true
        reaperOpacity = 0.85
        reaperScale = 1.6
        reaperShakeX = 0
        reaperShakeY = 0

        // 격렬한 흔들림 시작
        reaperShakeTimer?.invalidate()
        let rst = Timer(timeInterval: 0.04, repeats: true) { [self] _ in
            reaperShakeX = CGFloat.random(in: -20...20)
            reaperShakeY = CGFloat.random(in: -14...14)
        }
        RunLoop.main.add(rst, forMode: .common)
        reaperShakeTimer = rst

        // 강한 햅틱 연타
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // 0.8초 후 페이드아웃
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
    // MARK: - 라운드 클리어
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func roundCleared() {
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        phase = .success

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            successScale = 1.0
            successOpacity = 1.0
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        round += 1

        if round >= totalRounds {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [self] in
                guard alive else { return }
                alive = false
                onResult(.success)
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
        roundTimer?.invalidate()
        moveTimer?.invalidate()

        audioEngine?.fireFailureBlast()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

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
        roundTimer?.invalidate()
        moveTimer?.invalidate()
        reaperShakeTimer?.invalidate()
    }
}
