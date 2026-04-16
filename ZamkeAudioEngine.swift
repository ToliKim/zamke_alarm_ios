//
//  ZamkeAudioEngine.swift
//  ZAMKE
//
//  긴장 기반 사운드 엔진
//
//  Drone = 항상 존재하는 압박
//  Omen  = 전조 — 낮은 볼륨, 불규칙, 예측 불가
//  Ajaeng = 이벤트 — 희소한 놀람
//
//  핵심: 대부분 조용함 → 가끔 이상한 느낌 → 갑자기 사건 발생
//

import AVFoundation
import Combine

// MARK: - SoundBank

private struct SoundBank {
    let buffers: [AVAudioPCMBuffer]

    private static func findURL(name: String, folder: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/\(folder)") { return url }
        if let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: folder) { return url }
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") { return url }
        if let bp = Bundle.main.resourcePath {
            if let en = FileManager.default.enumerator(atPath: bp) {
                while let p = en.nextObject() as? String {
                    if p.hasSuffix("/\(name).wav") || p == "\(name).wav" {
                        return URL(fileURLWithPath: bp).appendingPathComponent(p)
                    }
                }
            }
        }
        return nil
    }

    static func load(folder: String, prefix: String, count: Int) -> SoundBank {
        var buffers: [AVAudioPCMBuffer] = []
        #if DEBUG
        if prefix == "d" {
            if let rp = Bundle.main.resourcePath, let en = FileManager.default.enumerator(atPath: rp) {
                var w: [String] = []
                while let p = en.nextObject() as? String { if p.hasSuffix(".wav") { w.append(p) } }
                print("🔍 번들 wav \(w.count)개")
            }
        }
        #endif
        for i in 1...count {
            let name = "\(prefix)\(i)"
            guard let url = findURL(name: name, folder: folder) else { continue }
            do {
                let file = try AVAudioFile(forReading: url)
                guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { continue }
                try file.read(into: buf)
                buffers.append(buf)
            } catch { }
        }
        print("✅ \(folder): \(buffers.count)/\(count)")
        return SoundBank(buffers: buffers)
    }

    func randomBuffer(excluding last: inout Int?) -> (buffer: AVAudioPCMBuffer, index: Int)? {
        guard !buffers.isEmpty else { return nil }
        var i: Int
        if buffers.count == 1 { i = 0 }
        else { repeat { i = Int.random(in: 0..<buffers.count) } while i == last }
        last = i
        return (buffers[i], i)
    }
}

// MARK: - ZamkeAudioEngine

final class ZamkeAudioEngine: ObservableObject {

    // ── 노드 ──
    private let engine = AVAudioEngine()
    private var mainMixer: AVAudioMixerNode { engine.mainMixerNode }

    private let dronePlayer = AVAudioPlayerNode()
    private let droneMixer  = AVAudioMixerNode()

    private let ajaengPlayer = AVAudioPlayerNode()
    private let ajaengMixer  = AVAudioMixerNode()
    private var ajaengPlaying = false

    private let omenPlayer = AVAudioPlayerNode()     // 기존 warningPlayer → omen
    private let omenMixer  = AVAudioMixerNode()
    private var omenPlaying = false

    // Zamke 전용 사운드 (z1~z5)
    private let zamkePlayer = AVAudioPlayerNode()
    private let zamkeMixer  = AVAudioMixerNode()
    private var zamkePlaying = false
    private var zamkeLoopTimer: Timer?

    // Moktak 리듬 미션용 (m1~m2)
    private let moktakPlayer = AVAudioPlayerNode()
    private let moktakMixer  = AVAudioMixerNode()

    // ── 사운드 뱅크 ──
    private var droneSounds:  SoundBank!
    private var ajaengSounds: SoundBank!
    private var omenSounds:   SoundBank!             // Warning 파일을 전조로 활용
    private var zamkeSounds:  SoundBank!             // Zamke z1~z5
    private var moktakSounds: SoundBank!             // Moktak m1~m2 (리듬 미션 탭)
    private var lastDroneIdx:  Int?
    private var lastAjaengIdx: Int?
    private var lastOmenIdx:   Int?
    private var lastZamkeIdx:  Int?
    private var lastMoktakIdx: Int?

    // ── 이벤트 스케줄러 ──
    private var tickTimer:   Timer?
    private var ajaengTimer: Timer?
    private var omenTimer:   Timer?

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 침묵 시스템
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // 이벤트 후 강제 침묵
    private var silenceUntil: Date = .distantPast

    // 무조건 비는 구간 (mandatory silence)
    private var mandatorySilenceUntil: Date = .distantPast

    private var inSilence: Bool {
        let now = Date()
        return now < silenceUntil || now < mandatorySilenceUntil
    }

    private func imposeSilence() {
        let duration = Double.random(in: currentPhase.parameters.silenceAfterEvent)
        silenceUntil = Date().addingTimeInterval(duration)
        #if DEBUG
        print("🤫 침묵 \(String(format: "%.1f", duration))초")
        #endif
    }

    // 이벤트 발생/스킵 후 mandatory silence 갱신
    private func refreshMandatorySilence() {
        let now = Date()
        if now >= mandatorySilenceUntil {
            // 현재 mandatory silence가 끝났으면 새로 설정
            let gap = Double.random(in: currentPhase.parameters.mandatorySilence)
            mandatorySilenceUntil = now.addingTimeInterval(gap)
            #if DEBUG
            print("🔇 필수 침묵 구간 \(String(format: "%.1f", gap))초")
            #endif
        }
    }

    // ━━ 연속 발사 방지 ━━
    private var lastEventType: String = ""       // "ajaeng" or "omen"
    private var lastEventTime: Date = .distantPast

    private var consecutiveBlocked: Bool {
        // 아쟁이 방금 발생했으면 아쟁 연속 금지
        // 같은 타입 이벤트가 5초 이내에 또 오면 차단
        return false // 이 체크는 fire 시점에서 개별 처리
    }

    // ── 상태 ──
    @Published private(set) var isRunning   = false
    @Published private(set) var isSuppressed = false

    var currentPhase: ZamkePhase = .infiltration
    private var phaseStartTime = Date()
    private var phaseDuration: Double = 20

    var overallIntensity: Double {
        let base = Double(currentPhase.rawValue) / 4.0
        let progress = min(Date().timeIntervalSince(phaseStartTime) / phaseDuration, 1.0)
        return min(base + progress * 0.25, 1.0)
    }

    // MARK: - Init

    init() {
        droneSounds  = SoundBank.load(folder: "Drone",   prefix: "d", count: 10)
        ajaengSounds = SoundBank.load(folder: "Ajaeng",  prefix: "a", count: 19)
        omenSounds   = SoundBank.load(folder: "Warning", prefix: "w", count: 12)
        zamkeSounds  = SoundBank.load(folder: "Zamke",   prefix: "z", count: 5)
        moktakSounds = SoundBank.load(folder: "Moktak",  prefix: "m", count: 2)
        buildGraph()
    }

    private func buildGraph() {
        engine.attach(dronePlayer); engine.attach(droneMixer)
        engine.connect(dronePlayer, to: droneMixer, format: nil)
        engine.connect(droneMixer,  to: mainMixer,  format: nil)

        engine.attach(ajaengPlayer); engine.attach(ajaengMixer)
        engine.connect(ajaengPlayer, to: ajaengMixer, format: nil)
        engine.connect(ajaengMixer,  to: mainMixer,   format: nil)

        engine.attach(omenPlayer); engine.attach(omenMixer)
        engine.connect(omenPlayer, to: omenMixer, format: nil)
        engine.connect(omenMixer,  to: mainMixer, format: nil)

        engine.attach(zamkePlayer); engine.attach(zamkeMixer)
        engine.connect(zamkePlayer, to: zamkeMixer, format: nil)
        engine.connect(zamkeMixer,  to: mainMixer,  format: nil)

        engine.attach(moktakPlayer); engine.attach(moktakMixer)
        engine.connect(moktakPlayer, to: moktakMixer, format: nil)
        engine.connect(moktakMixer,  to: mainMixer,   format: nil)
    }

    // MARK: - Start / Stop

    func start() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        do { try engine.start() } catch { print("❌ \(error)"); return }

        isRunning = true
        currentPhase = .infiltration
        phaseStartTime = Date()
        phaseDuration = Double.random(in: currentPhase.durationRange)
        silenceUntil = .distantPast
        mandatorySilenceUntil = .distantPast
        lastEventType = ""
        lastEventTime = .distantPast

        startDrone()

        // 초기 mandatory silence — 시작 직후 5~10초 드론만
        mandatorySilenceUntil = Date().addingTimeInterval(Double.random(in: 5...10))

        scheduleAjaengEvent()
        scheduleOmenEvent()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        tickTimer?.invalidate();  tickTimer = nil
        ajaengTimer?.invalidate(); ajaengTimer = nil
        omenTimer?.invalidate();   omenTimer = nil
        zamkeLoopTimer?.invalidate(); zamkeLoopTimer = nil

        fadeVolume(droneMixer,  to: 0, duration: 0.3)
        fadeVolume(ajaengMixer, to: 0, duration: 0.2)
        fadeVolume(omenMixer,   to: 0, duration: 0.2)
        fadeVolume(zamkeMixer,  to: 0, duration: 0.2)
        fadeVolume(moktakMixer, to: 0, duration: 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.dronePlayer.stop()
            self?.ajaengPlayer.stop(); self?.ajaengPlaying = false
            self?.omenPlayer.stop();   self?.omenPlaying = false
            self?.zamkePlayer.stop();  self?.zamkePlaying = false
            self?.moktakPlayer.stop()
            self?.engine.stop()
            self?.isRunning = false
        }
    }

    // MARK: - Phase

    func setPhase(_ phase: ZamkePhase) {
        currentPhase = phase
        phaseStartTime = Date()
        phaseDuration = Double.random(in: phase.durationRange)

        fadeVolume(droneMixer, to: phase.parameters.droneVolume, duration: 2.0)

        #if DEBUG
        print("📊 [\(phase.displayName)] drone=\(phase.parameters.droneVolume)")
        #endif
    }

    func escalate() {
        if currentPhase != .domination { setPhase(currentPhase.next) }
    }

    // MARK: - Suppression

    func beginSuppression() {
        isSuppressed = true
        fadeVolume(droneMixer,  to: currentPhase.parameters.droneVolume * 0.4, duration: 0.5)
        fadeVolume(ajaengMixer, to: ajaengMixer.outputVolume * 0.2, duration: 0.3)
        fadeVolume(omenMixer,   to: omenMixer.outputVolume * 0.2, duration: 0.3)
    }

    func endSuppression() {
        isSuppressed = false
        fadeVolume(droneMixer, to: currentPhase.parameters.droneVolume, duration: 0.8)
    }

    // MARK: - External Triggers

    func fireAjaeng() {
        if ajaengPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.fireAjaengNow()
            }
        } else {
            fireAjaengNow()
        }
    }

    func fireWarning() {
        // 외부 호출 호환 — 전조 발사
        if !omenPlaying { fireOmenNow() }
    }

    // MARK: - Tick

    private func tick() {
        // 자동 상태 전이
        if currentPhase != .domination && Date().timeIntervalSince(phaseStartTime) >= phaseDuration {
            escalate()
        }

        // 드론 미세 숨쉬기
        if !isSuppressed {
            let t = currentPhase.parameters.droneVolume
            let v = droneMixer.outputVolume + Float.random(in: -0.006...0.006)
            droneMixer.outputVolume = max(t - 0.02, min(v, t + 0.02))
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Drone
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startDrone() {
        guard let (buf, _) = droneSounds.randomBuffer(excluding: &lastDroneIdx) else { return }
        dronePlayer.stop()
        dronePlayer.scheduleBuffer(buf, at: nil, options: .loops)
        dronePlayer.play()
        droneMixer.outputVolume = currentPhase.parameters.droneVolume
        scheduleDroneSwap()
    }

    private func scheduleDroneSwap() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 50...120)) { [weak self] in
            guard let self = self, self.engine.isRunning else { return }
            guard let (buf, _) = self.droneSounds.randomBuffer(excluding: &self.lastDroneIdx) else { return }
            let vol = self.droneMixer.outputVolume
            self.fadeVolume(self.droneMixer, to: vol * 0.4, duration: 3.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.dronePlayer.stop()
                self.dronePlayer.scheduleBuffer(buf, at: nil, options: .loops)
                self.dronePlayer.play()
                self.fadeVolume(self.droneMixer, to: vol, duration: 3.5)
            }
            self.scheduleDroneSwap()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Ajaeng 이벤트 (놀람)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func scheduleAjaengEvent() {
        ajaengTimer?.invalidate()
        let p = currentPhase.parameters
        guard p.ajaengEnabled else { return }

        let wait = Double.random(in: p.ajaengMinInterval...p.ajaengMaxInterval)

        #if DEBUG
        print("🎵 아쟁 예약: \(String(format: "%.0f", wait))초 후 (확률 \(Int(p.ajaengProbability * 100))%)")
        #endif

        ajaengTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let pp = self.currentPhase.parameters

            // 4중 체크: 확률 + 침묵 + 재생 중 + 억제 + 연속 방지
            let roll = Double.random(in: 0...1)
            let timeSinceLast = Date().timeIntervalSince(self.lastEventTime)
            let shouldFire = roll < pp.ajaengProbability
                && !self.inSilence
                && !self.ajaengPlaying
                && !self.isSuppressed
                && !(self.lastEventType == "ajaeng" && timeSinceLast < 8)  // 아쟁 연속 8초 금지

            if shouldFire {
                self.fireAjaengNow()
            } else {
                // 스킵해도 mandatory silence 갱신
                self.refreshMandatorySilence()
                #if DEBUG
                print("🎵 아쟁 스킵 (roll=\(String(format: "%.2f", roll)) silence=\(self.inSilence) last=\(self.lastEventType))")
                #endif
            }

            self.scheduleAjaengEvent()
        }
    }

    private func fireAjaengNow() {
        guard !ajaengPlaying else { return }
        guard let (buf, _) = ajaengSounds.randomBuffer(excluding: &lastAjaengIdx) else { return }

        let vol = Float.random(in: currentPhase.parameters.ajaengVolume)
        ajaengPlayer.volume = vol

        ajaengPlaying = true
        ajaengPlayer.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async { self?.ajaengPlaying = false }
        }
        ajaengPlayer.play()

        lastEventType = "ajaeng"
        lastEventTime = Date()

        // 아쟁 후에는 긴 침묵
        imposeSilence()
        refreshMandatorySilence()

        #if DEBUG
        print("🎵 아쟁! vol=\(String(format: "%.2f", vol)) [\(currentPhase.displayName)]")
        #endif
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Omen 전조 (기존 Warning → 역할 변경)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func scheduleOmenEvent() {
        omenTimer?.invalidate()
        let p = currentPhase.parameters
        guard p.omenEnabled else { return }

        let wait = Double.random(in: p.omenMinInterval...p.omenMaxInterval)

        #if DEBUG
        print("👁 전조 예약: \(String(format: "%.0f", wait))초 후 (확률 \(Int(p.omenProbability * 100))%)")
        #endif

        omenTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let pp = self.currentPhase.parameters

            let roll = Double.random(in: 0...1)
            let shouldFire = roll < pp.omenProbability
                && !self.inSilence
                && !self.omenPlaying
                && !self.isSuppressed

            if shouldFire {
                self.fireOmenNow()
            }
            #if DEBUG
            if !shouldFire {
                print("👁 전조 스킵 (roll=\(String(format: "%.2f", roll)) silence=\(self.inSilence))")
            }
            #endif

            self.scheduleOmenEvent()
        }
    }

    private func fireOmenNow() {
        guard !omenPlaying else { return }
        guard let (buf, _) = omenSounds.randomBuffer(excluding: &lastOmenIdx) else { return }

        // 전조는 매우 낮은 볼륨 — 거의 들릴까말까
        let vol = Float.random(in: currentPhase.parameters.omenVolume)
        omenPlayer.volume = vol

        omenPlaying = true
        omenPlayer.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async { self?.omenPlaying = false }
        }
        omenPlayer.play()

        lastEventType = "omen"
        lastEventTime = Date()

        // 전조 후에는 짧은 침묵만 (3~5초)
        let shortSilence = Double.random(in: 3.0...5.0)
        silenceUntil = Date().addingTimeInterval(shortSilence)

        #if DEBUG
        print("👁 전조! vol=\(String(format: "%.2f", vol)) [\(currentPhase.displayName)]")
        #endif
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Zamke 사운드 (z1~z5)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// 화들짝 시작 시 z1 재생
    func playZamkeStart() {
        guard !zamkeSounds.buffers.isEmpty else { return }
        let buf = zamkeSounds.buffers[0]  // z1 고정
        zamkeMixer.outputVolume = 0.9
        zamkePlaying = true
        zamkePlayer.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async { self?.zamkePlaying = false }
        }
        zamkePlayer.play()
        #if DEBUG
        print("🔊 Zamke z1 시작!")
        #endif
    }

    /// z1~z5 랜덤으로 한 번만 재생 (실패 시 단발)
    func playZamkeOnce() {
        fireZamkeRandom()
    }

    /// 미션 실패 시 z1~z5 랜덤 재생 + 이후 드문드문 반복
    func startZamkeFailLoop() {
        // 즉시 한 번 랜덤 재생
        fireZamkeRandom()
        // 드문드문 반복 스케줄 (5~12초 간격)
        scheduleZamkeLoop()
    }

    /// 미션 수행 중 → Zamke 사운드 정지
    func stopZamke() {
        zamkeLoopTimer?.invalidate()
        zamkeLoopTimer = nil
        if zamkePlaying {
            fadeVolume(zamkeMixer, to: 0, duration: 0.3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.zamkePlayer.stop()
                self?.zamkePlaying = false
                self?.zamkeMixer.outputVolume = 0.9
            }
        }
        #if DEBUG
        print("🔇 Zamke 정지")
        #endif
    }

    private func fireZamkeRandom() {
        guard !zamkePlaying else { return }
        guard let (buf, _) = zamkeSounds.randomBuffer(excluding: &lastZamkeIdx) else { return }
        let vol = Float.random(in: 0.7...1.0)
        zamkeMixer.outputVolume = vol
        zamkePlaying = true
        zamkePlayer.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async { self?.zamkePlaying = false }
        }
        zamkePlayer.play()
        #if DEBUG
        print("🔊 Zamke 랜덤! vol=\(String(format: "%.2f", vol))")
        #endif
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Moktak (리듬 미션 탭 사운드)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// 리듬 미션에서 탭할 때마다 호출 — m1/m2 랜덤 재생
    func playMoktak() {
        guard engine.isRunning else { return }
        guard let (buf, _) = moktakSounds.randomBuffer(excluding: &lastMoktakIdx) else { return }
        moktakMixer.outputVolume = 1.0
        // 연타 대응: 현재 재생 중인 버퍼를 인터럽트하고 새 버퍼를 재생
        moktakPlayer.scheduleBuffer(buf, at: nil, options: .interrupts)
        moktakPlayer.play()
        #if DEBUG
        print("🪘 Moktak!")
        #endif
    }

    private func scheduleZamkeLoop() {
        zamkeLoopTimer?.invalidate()
        let wait = Double.random(in: 5.0...12.0)
        zamkeLoopTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.fireZamkeRandom()
            self.scheduleZamkeLoop()  // 다시 예약
        }
    }

    // MARK: - Fade

    private func fadeVolume(_ mixer: AVAudioMixerNode, to target: Float, duration: Double) {
        let steps = max(Int(duration / 0.05), 1)
        let current = mixer.outputVolume
        let delta = (target - current) / Float(steps)
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                mixer.outputVolume = current + delta * Float(i + 1)
            }
        }
    }
}
