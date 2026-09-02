import Combine
import SwiftUI
import WatchKit

protocol HapticPlaying {
    func playWall()
    func playPaddle()
    func playScore(playerPoint: Bool)
}

struct WatchHaptics: HapticPlaying {
    func playWall() {
        WKInterfaceDevice.current().play(.click)
    }

    func playPaddle() {
        WKInterfaceDevice.current().play(.start)
    }

    func playScore(playerPoint: Bool) {
        WKInterfaceDevice.current().play(playerPoint ? .success : .failure)
    }
}

struct SilentHaptics: HapticPlaying {
    func playWall() {}
    func playPaddle() {}
    func playScore(playerPoint: Bool) {}
}

@MainActor
@Observable
final class PongGame {
    private(set) var engine: PongEngine
    private(set) var isRunning = false

    private var timer: AnyCancellable?
    private var lastTick: Date?
    private let haptics: any HapticPlaying

    init(
        courtSize: CGSize = CGSize(width: 198, height: 242),
        haptics: any HapticPlaying = WatchHaptics()
    ) {
        self.engine = PongEngine(courtSize: courtSize)
        self.haptics = haptics
    }

    var playerPaddleY: CGFloat {
        get { engine.playerPaddleY }
        set { engine.setPlayerPaddleY(newValue) }
    }

    var aiPaddleY: CGFloat { engine.aiPaddleY }
    var ballPosition: CGPoint { engine.ballPosition }
    var trail: [CGPoint] { engine.trail }
    var playerScore: Int { engine.playerScore }
    var aiScore: Int { engine.aiScore }
    var metrics: PongMetrics { engine.metrics }
    var phase: PongPhase { engine.phase }
    var paddleMinY: CGFloat { engine.metrics.minPaddleY }
    var paddleMaxY: CGFloat { engine.metrics.maxPaddleY }

    func resize(to size: CGSize) {
        engine.resize(to: size)
    }

    func start() {
        guard timer == nil else {
            isRunning = true
            return
        }
        lastTick = Date()
        isRunning = true
        timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick(now: date)
            }
    }

    func pause() {
        isRunning = false
        lastTick = nil
    }

    func stop() {
        pause()
        timer?.cancel()
        timer = nil
    }

    func resetMatch() {
        engine.resetMatch()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            start()
        } else {
            pause()
        }
    }

    func tick(now: Date) {
        guard isRunning else { return }
        let dt: TimeInterval
        if let lastTick {
            dt = now.timeIntervalSince(lastTick)
        } else {
            dt = 1.0 / 30.0
        }
        lastTick = now
        engine.step(dt: dt)
        playHaptic(for: engine.lastEvent)
    }

    private func playHaptic(for event: PongEvent?) {
        switch event {
        case .wall:
            haptics.playWall()
        case .paddle:
            haptics.playPaddle()
        case .scored(let byPlayer):
            haptics.playScore(playerPoint: byPlayer)
        case .none:
            break
        }
    }
}
