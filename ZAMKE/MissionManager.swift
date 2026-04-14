//
//  MissionManager.swift
//  ZAMKE
//
//  5단계 미션 시스템
//  추적 → 기억 → 리듬 → 반응 → 종료
//

import SwiftUI
import Combine

// MARK: - 미션 타입

enum MissionType: Int, CaseIterable {
    case tracking  = 0  // 1단계: 움직이는 점 추적 (3초 유지)
    case memory    = 1  // 2단계: 점 패턴 기억 후 입력
    case rhythm    = 2  // 3단계: 박자에 맞춰 터치
    case reaction  = 3  // 4단계: 랜덤 위치 빠르게 터치
    case finalQuiz = 4  // 5단계: 간단한 계산 문제

    var displayName: String {
        switch self {
        case .tracking:  return "추적"
        case .memory:    return "기억"
        case .rhythm:    return "리듬"
        case .reaction:  return "반응"
        case .finalQuiz: return "종료"
        }
    }

    var instruction: String {
        switch self {
        case .tracking:  return "움 직 이 는  점 을  따 라 가 세 요"
        case .memory:    return "패 턴 을  기 억 하 세 요"
        case .rhythm:    return "박 자 에  맞 춰  터 치 하 세 요"
        case .reaction:  return "나 타 나 는  점 을  터 치 하 세 요"
        case .finalQuiz: return "문 제 를  풀 어 주 세 요"
        }
    }

    var next: MissionType? {
        MissionType(rawValue: rawValue + 1)
    }
}

// MARK: - 미션 결과

enum MissionResult {
    case success
    case failure
}

// MARK: - MissionManager

final class MissionManager: ObservableObject {

    @Published var currentMission: MissionType = .tracking
    @Published var missionActive: Bool = false
    @Published var failCount: Int = 0
    @Published var totalCleared: Int = 0
    @Published var isCompleted: Bool = false
    @Published var missionAttemptID: UUID = UUID()  // 뷰 재생성 트리거

    var difficulty: Double {
        min(1.0 + Double(failCount) * 0.3, 3.0)
    }

    var onMissionSuccess: (() -> Void)?
    var onMissionFail: (() -> Void)?
    var onAllCleared: (() -> Void)?

    func startMission() {
        currentMission = .tracking
        missionActive = true
        failCount = 0
        totalCleared = 0
        isCompleted = false
        missionAttemptID = UUID()
    }

    @Published var transitioning: Bool = false  // 미션 전환 중 (1.5초 대기)

    func reportResult(_ result: MissionResult) {
        switch result {
        case .success:
            totalCleared += 1
            if let next = currentMission.next {
                onMissionSuccess?()
                // 1.5초 대기 후 다음 미션
                transitioning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                    currentMission = next
                    missionAttemptID = UUID()
                    transitioning = false
                }
            } else {
                isCompleted = true
                missionActive = false
                onAllCleared?()
            }

        case .failure:
            failCount += 1
            missionAttemptID = UUID()  // 실패 시에도 뷰 재생성
            onMissionFail?()
        }
    }
}

// MARK: - 1단계: 추적 미션

struct TrackingMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void

    @State private var targetPos = CGPoint(x: 200, y: 400)
    @State private var nextTargetPos = CGPoint(x: 200, y: 400)
    @State private var fingerPos: CGPoint? = nil
    @State private var holdTime: Double = 0
    @State private var holdTimer: Timer?
    @State private var alive = true
    private let requiredHold: Double = 5.0
    private let targetRadius: CGFloat = 55

    private var fingerOnTarget: Bool {
        guard let fp = fingerPos else { return false }
        return hypot(fp.x - targetPos.x, fp.y - targetPos.y) < targetRadius * 2.2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 타겟 원
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.8), Color.red.opacity(0.2)],
                            center: .center, startRadius: 0, endRadius: targetRadius
                        )
                    )
                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                    .position(targetPos)

                // 진행률 링
                Circle()
                    .trim(from: 0, to: holdTime / requiredHold)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: targetRadius * 2 + 14, height: targetRadius * 2 + 14)
                    .rotationEffect(.degrees(-90))
                    .position(targetPos)

                VStack {
                    Spacer()
                    Text("점 을  \(Int(requiredHold)) 초 간  따 라 가 세 요")
                        .font(.system(size: 12, weight: .thin, design: .serif))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 20)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        fingerPos = value.location
                    }
                    .onEnded { _ in
                        fingerPos = nil
                    }
            )
            .onAppear {
                targetPos = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                startMovement(in: geo.size)
                startHoldCheck()
            }
            .onDisappear {
                alive = false
                holdTimer?.invalidate()
            }
        }
    }

    // 연속 이동 — Timer 대신 DispatchQueue로 재귀 호출
    private func startMovement(in size: CGSize) {
        guard alive else { return }
        let moveDuration = max(1.5, 3.0 / difficulty)

        let newPos = CGPoint(
            x: CGFloat.random(in: 60...(size.width - 60)),
            y: CGFloat.random(in: 120...(size.height - 160))
        )

        withAnimation(.easeInOut(duration: moveDuration)) {
            targetPos = newPos
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + moveDuration) { [self] in
            startMovement(in: size)
        }
    }

    private func startHoldCheck() {
        holdTime = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard alive else { return }
            if fingerOnTarget {
                holdTime += 0.1
                if holdTime >= requiredHold {
                    alive = false
                    holdTimer?.invalidate()
                    onResult(.success)
                }
            } else {
                // 진행 중 놓으면 감소 (바로 실패는 아님)
                holdTime = max(0, holdTime - 0.05)
            }
        }
    }
}

// MARK: - 2단계: 기억 미션

struct MemoryMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void

    @State private var pattern: [Int] = []
    @State private var userInput: [Int] = []
    @State private var phase: MemoryPhase = .showing
    @State private var highlightIndex: Int? = nil
    @State private var currentShowIdx = 0
    @State private var alive = true

    // 유휴 타이머 — 3초간 아무 조작 없으면 자동 실패
    @State private var idleTimeLeft: Double = 3.0
    @State private var idleTimer: Timer?

    private enum MemoryPhase {
        case showing    // 패턴 표시 중
        case input      // 터치 입력
    }

    private var gridCount: Int { 4 }       // 4x4 = 16칸
    private let patternLength: Int = 4     // 빨간 네모 4개 맞추기
    private let idleLimit: Double = 3.0    // 3초 유휴 → 실패

    var body: some View {
        VStack(spacing: 20) {
            // 상태별 안내 텍스트
            Group {
                switch phase {
                case .showing:
                    Text("패 턴 을  기 억 하 세 요")
                        .font(.system(size: 13, weight: .thin, design: .serif))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.3))
                case .input:
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("같 은  순 서 로  터 치")
                                .font(.system(size: 13, weight: .thin, design: .serif))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.3))

                            Text("\(userInput.count) / \(patternLength)")
                                .font(.system(size: 12, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                        }

                        // 유휴 프로그레스 바 — 3초 바가 줄어듦
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 2)

                                Rectangle()
                                    .fill(idleTimeLeft < 1.0
                                          ? Color.red.opacity(0.7)
                                          : Color.white.opacity(0.2))
                                    .frame(width: geo.size.width * (idleTimeLeft / idleLimit), height: 2)
                                    .animation(.linear(duration: 0.1), value: idleTimeLeft)
                            }
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 40)
                    }
                }
            }

            // 4x4 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gridCount), spacing: 8) {
                ForEach(0..<(gridCount * gridCount), id: \.self) { idx in
                    Rectangle()
                        .fill(cellColor(for: idx))
                        .frame(height: 65)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard phase == .input else { return }
                            handleTap(idx)
                        }
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear { generateAndShow() }
        .onDisappear {
            alive = false
            idleTimer?.invalidate()
        }
    }

    private func cellColor(for idx: Int) -> Color {
        if highlightIndex == idx {
            return Color.red.opacity(0.9)
        }
        if phase == .input && userInput.contains(idx) {
            return Color.green.opacity(0.4)
        }
        return Color.white.opacity(0.08)
    }

    // MARK: - 패턴 생성 & 표시

    private func generateAndShow() {
        let total = gridCount * gridCount
        var p: [Int] = []
        while p.count < patternLength {
            let r = Int.random(in: 0..<total)
            if !p.contains(r) { p.append(r) }
        }
        pattern = p
        phase = .showing
        currentShowIdx = 0
        showNext()
    }

    private func showNext() {
        guard currentShowIdx < pattern.count else {
            highlightIndex = nil
            // 패턴 표시 끝 → 바로 입력 시작 (0.5초 짧은 숨 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard alive else { return }
                phase = .input
                startIdleTimer()
            }
            return
        }
        // 패턴 하나씩 보여주기 — 0.8초 표시 + 0.3초 간격
        highlightIndex = pattern[currentShowIdx]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            highlightIndex = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentShowIdx += 1
                showNext()
            }
        }
    }

    // MARK: - 유휴 타이머 (3초 머뭇거림 → 실패)

    /// 입력 시작 or 탭할 때마다 3초로 리셋
    private func startIdleTimer() {
        idleTimeLeft = idleLimit
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard alive, phase == .input else { return }
            idleTimeLeft -= 0.1
            if idleTimeLeft <= 0 {
                idleTimer?.invalidate()
                idleTimer = nil
                onResult(.failure)
            }
        }
    }

    /// 탭할 때마다 유휴 타이머 리셋
    private func resetIdleTimer() {
        idleTimeLeft = idleLimit
    }

    // MARK: - 입력 처리

    private func handleTap(_ idx: Int) {
        // 유휴 타이머 리셋 — 탭했으니까 머뭇거림 아님
        resetIdleTimer()

        let expected = pattern[userInput.count]
        userInput.append(idx)

        if idx != expected {
            idleTimer?.invalidate()
            idleTimer = nil
            onResult(.failure)
            return
        }
        if userInput.count == pattern.count {
            idleTimer?.invalidate()
            idleTimer = nil
            onResult(.success)
        }
    }
}

// MARK: - 3단계: 리듬 미션 (링 수축 → 겹칠 때 탭)
//
// 매 라운드마다 원의 크기·위치가 랜덤으로 변함
// 링이 원과 겹치는 순간 탭 → 초록 / 놓치면 → 빨강
// 총 5회, 3회 이상 성공 시 통과

struct RhythmMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void
    var audioEngine: ZamkeAudioEngine?   // 목탁 사운드용

    @State private var alive = true
    @State private var round = 0
    @State private var successCount = 0
    private let totalRounds = 5
    private let passCount = 3  // 3/5만 맞추면 통과

    // 링 애니메이션
    @State private var ringScale: CGFloat = 3.0
    @State private var ringOpacity: Double = 0.0
    @State private var ringAnimating = false
    @State private var tapped = false

    // 피드백
    @State private var feedbackColor: Color = .clear
    @State private var feedbackScale: CGFloat = 1.0
    @State private var feedbackText: String = ""

    // 매 라운드 랜덤 크기·위치
    @State private var targetSize: CGFloat = 130
    @State private var targetOffset: CGSize = .zero

    // 링 수축 시간
    @State private var shrinkDuration: Double = 1.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 점수
                VStack {
                    Text("\(successCount) / \(totalRounds)")
                        .font(.system(size: 14, weight: .thin, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 30)
                    Spacer()
                }

                // 게임 영역 — 매번 다른 위치
                ZStack {
                    // 수축하는 링
                    Circle()
                        .stroke(Color.red.opacity(0.7 * ringOpacity), lineWidth: 3)
                        .frame(width: targetSize, height: targetSize)
                        .scaleEffect(ringScale)

                    // 타겟 원
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: targetSize, height: targetSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                        )

                    // 피드백 원
                    Circle()
                        .fill(feedbackColor)
                        .frame(width: targetSize, height: targetSize)
                        .scaleEffect(feedbackScale)
                        .allowsHitTesting(false)

                    // 피드백 텍스트
                    Text(feedbackText)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.8))
                        .offset(y: -targetSize * 0.7)
                }
                .offset(targetOffset)
                .contentShape(Circle().scale(3.0))
                .onTapGesture { handleTap() }

                // 안내
                VStack {
                    Spacer()
                    Text("링 이  원 과  겹 칠  때  터 치")
                        .font(.system(size: 11, weight: .thin, design: .serif))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.bottom, 30)
                }
            }
            .onAppear { startRound(in: geo.size) }
            .onDisappear { alive = false }
        }
    }

    private func startRound(in size: CGSize) {
        guard alive, round < totalRounds else { return }
        tapped = false
        feedbackText = ""
        feedbackColor = .clear
        feedbackScale = 1.0

        // 매 라운드 랜덤 크기 (90~160)
        targetSize = CGFloat.random(in: 90...160)

        // 랜덤 위치 (화면 중앙 기준 오프셋, 원이 화면 밖으로 안 나가게)
        let maxX = (size.width / 2) - targetSize * 0.8
        let maxY = (size.height / 2) - targetSize * 1.2
        withAnimation(.easeOut(duration: 0.3)) {
            targetOffset = CGSize(
                width: CGFloat.random(in: -maxX...maxX),
                height: CGFloat.random(in: -maxY * 0.5...maxY * 0.4)
            )
        }

        // 수축 시간 넉넉하게 (1.2~2.0초)
        shrinkDuration = Double.random(in: 1.2...2.0)

        // 링 초기화
        ringScale = 3.0
        ringOpacity = 1.0
        ringAnimating = true

        // 링 수축 애니메이션
        withAnimation(.easeIn(duration: shrinkDuration)) {
            ringScale = 1.0
        }

        // 수축 완료 후 → 탭 안 했으면 놓침
        DispatchQueue.main.asyncAfter(deadline: .now() + shrinkDuration + 0.4) {
            guard alive else { return }
            if !tapped {
                showFeedback(hit: false, in: size)
            }
        }
    }

    private func handleTap() {
        guard alive, ringAnimating, !tapped else { return }
        tapped = true
        ringAnimating = false

        // 탭할 때마다 목탁 사운드
        audioEngine?.playMoktak()

        let diff = abs(ringScale - 1.0)
        let isHit = diff < 0.5  // 매우 넉넉한 판정

        showFeedback(hit: isHit, in: .zero)
    }

    private func showFeedback(hit: Bool, in size: CGSize) {
        ringAnimating = false

        if hit {
            successCount += 1
            feedbackColor = Color.green.opacity(0.5)
            feedbackText = "G O O D"
            withAnimation(.easeOut(duration: 0.1)) { feedbackScale = 1.2 }
        } else {
            feedbackColor = Color.red.opacity(0.3)
            feedbackText = "M I S S"
            withAnimation(.easeOut(duration: 0.1)) { feedbackScale = 0.9 }
        }

        withAnimation(.easeOut(duration: 0.15)) { ringOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard alive else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                feedbackColor = .clear
                feedbackScale = 1.0
            }

            round += 1
            if round >= totalRounds {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard alive else { return }
                    if successCount >= passCount { onResult(.success) }
                    else { onResult(.failure) }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // GeometryReader에서 size를 다시 가져오기 위해 재귀 호출하지 않고
                    // onAppear에서 시작한 것처럼 startRound를 호출
                    // size가 .zero면 기본값 사용
                    startRound(in: UIScreen.main.bounds.size)
                }
            }
        }
    }
}

// MARK: - 4단계: 반응 미션

struct ReactionMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void

    @State private var dotPos = CGPoint(x: 200, y: 400)
    @State private var dotVisible = false
    @State private var hitCount = 0
    @State private var missCount = 0
    @State private var roundTimer: Timer?
    private let totalRounds = 4          // 6→4 라운드
    private var timeLimit: Double { max(3.0, 5.0 / difficulty) }  // 훨씬 넉넉

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if dotVisible {
                    // 점 크기 80 + 밝은 glow로 잘 보이게
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 120, height: 120)
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 80, height: 80)
                    }
                    .position(dotPos)
                    .contentShape(Circle().scale(1.8))
                    .onTapGesture {
                        hitCount += 1
                        dotVisible = false
                        roundTimer?.invalidate()
                        checkOrNext(in: geo.size)
                    }
                }

                VStack {
                    Spacer()
                    Text("남 은  \(totalRounds - hitCount - missCount) 개")
                        .font(.system(size: 12, weight: .thin, design: .serif))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.bottom, 20)
                }
            }
            .onAppear { spawnDot(in: geo.size) }
            .onDisappear { roundTimer?.invalidate() }
        }
    }

    private func spawnDot(in size: CGSize) {
        dotPos = CGPoint(
            x: CGFloat.random(in: 50...(size.width - 50)),
            y: CGFloat.random(in: 100...(size.height - 150))
        )
        dotVisible = true

        roundTimer = Timer.scheduledTimer(withTimeInterval: timeLimit, repeats: false) { _ in
            // 시간 초과
            missCount += 1
            dotVisible = false
            checkOrNext(in: size)
        }
    }

    private func checkOrNext(in size: CGSize) {
        if hitCount + missCount >= totalRounds {
            if hitCount >= totalRounds - 2 { onResult(.success) }  // 2개 틀려도 통과
            else { onResult(.failure) }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.3...0.8)) {
                spawnDot(in: size)
            }
        }
    }
}

// MARK: - 5단계: 종료 미션 (계산 문제)

struct FinalQuizMissionView: View {
    let difficulty: Double
    let onResult: (MissionResult) -> Void

    @State private var question = ""
    @State private var answer = 0
    @State private var userAnswer = ""
    @State private var timeLeft: Double = 15
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            // 타이머
            Text(String(format: "%.0f", timeLeft))
                .font(.system(size: 14, weight: .ultraLight, design: .monospaced))
                .tracking(3)
                .foregroundColor(timeLeft < 5 ? .red.opacity(0.7) : .white.opacity(0.3))

            // 문제
            Text(question)
                .font(.system(size: 32, weight: .thin, design: .serif))
                .tracking(4)
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .white.opacity(0.05), radius: 10)

            // 입력
            if options.count == 4 {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        Button(action: {
                            if options[i] == answer { onResult(.success) }
                            else { onResult(.failure) }
                            timer?.invalidate()
                        }) {
                            Text("\(options[i])")
                                .font(.system(size: 20, weight: .light, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 68, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.06))
                                        )
                                )
                        }
                    }
                }
            }
        }
        .onAppear {
            generateQuestion()
            startTimer()
        }
        .onDisappear { timer?.invalidate() }
    }

    @State private var options: [Int] = []

    private func generateQuestion() {
        let a = Int.random(in: 10...50)
        let b = Int.random(in: 10...50)
        let ops: [(String, (Int, Int) -> Int)] = [
            ("+", { $0 + $1 }),
            ("-", { $0 - $1 }),
            ("×", { $0 * $1 })
        ]
        let op = ops[Int.random(in: 0..<(difficulty > 2 ? 3 : 2))]
        question = "\(a) \(op.0) \(b) = ?"
        answer = op.1(a, b)

        var opts = [answer]
        while opts.count < 4 {
            let fake = answer + Int.random(in: -10...10)
            if fake != answer && !opts.contains(fake) { opts.append(fake) }
        }
        options = opts.shuffled()
    }

    private func startTimer() {
        timeLeft = max(8, 15 / difficulty)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeLeft -= 1
            if timeLeft <= 0 {
                timer?.invalidate()
                onResult(.failure)
            }
        }
    }
}
