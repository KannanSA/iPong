import CoreGraphics
import Testing
@testable import iPong_Watch_App

struct TrackingOpponentTests {
    let metrics = PongMetrics(courtSize: CGSize(width: 200, height: 200))
    let opponent = TrackingOpponent()

    @Test func interceptReflectsProjectedPathOffWalls() {
        let y = opponent.reflect(y: 230, min: 5, max: 195)
        #expect(abs(y - 160) < 0.001)
    }

    @Test func coreMLOpponentFallsBackWithoutModel() {
        let fallback = CoreMLOpponent(predictor: nil)
        let snapshot = PongSnapshot(
            courtSize: metrics.courtSize,
            ballPosition: CGPoint(x: 40, y: 50),
            ballVelocity: CGVector(dx: 80, dy: 10),
            playerPaddleY: 100,
            aiPaddleY: 100
        )
        let y = fallback.desiredPaddleY(snapshot: snapshot, dt: 1.0 / 30.0, metrics: metrics)
        #expect(y >= metrics.minPaddleY)
        #expect(y <= metrics.maxPaddleY)
    }

    @Test func coreMLPredictorOverridesTrackingTarget() {
        let stub = StubPredictor(value: 60)
        let opponent = CoreMLOpponent(predictor: stub)
        let snapshot = PongSnapshot(
            courtSize: metrics.courtSize,
            ballPosition: CGPoint(x: 40, y: 160),
            ballVelocity: CGVector(dx: 80, dy: 0),
            playerPaddleY: 100,
            aiPaddleY: 100
        )
        let y = opponent.desiredPaddleY(snapshot: snapshot, dt: 1.0 / 30.0, metrics: metrics)
        #expect(abs(y - 60) < 0.001)
    }
}

struct PongEngineTests {
    let court = CGSize(width: 200, height: 200)

    @Test func paddleYIsClampedToCourt() {
        var engine = PongEngine(courtSize: court, opponent: TrackingOpponent())
        engine.setPlayerPaddleY(-40)
        #expect(engine.playerPaddleY == engine.metrics.minPaddleY)
        engine.setPlayerPaddleY(400)
        #expect(engine.playerPaddleY == engine.metrics.maxPaddleY)
    }

    @Test func ballBouncesOffTopWall() {
        var engine = playingEngine(ball: CGPoint(x: 100, y: 6), velocity: CGVector(dx: 20, dy: -80))
        engine.step(dt: 0.05)
        #expect(engine.ballVelocity.dy > 0)
        #expect(engine.lastEvent == .wall)
    }

    @Test func ballBouncesOffBottomWall() {
        var engine = playingEngine(ball: CGPoint(x: 100, y: 194), velocity: CGVector(dx: 20, dy: 80))
        engine.step(dt: 0.05)
        #expect(engine.ballVelocity.dy < 0)
        #expect(engine.lastEvent == .wall)
    }

    @Test func playerPaddleDeflectsIncomingBall() {
        var engine = playingEngine(
            ball: CGPoint(x: 22, y: 100),
            velocity: CGVector(dx: -120, dy: 0)
        )
        engine.playerPaddleY = 100
        engine.step(dt: 0.04)
        #expect(engine.ballVelocity.dx > 0)
        #expect(engine.lastEvent == .paddle)
    }

    @Test func outgoingBallDoesNotStickToPlayerPaddle() {
        var engine = playingEngine(
            ball: CGPoint(x: 22, y: 100),
            velocity: CGVector(dx: 120, dy: 0)
        )
        engine.playerPaddleY = 100
        engine.step(dt: 0.04)
        #expect(engine.ballVelocity.dx > 0)
        #expect(engine.lastEvent != .paddle)
    }

    @Test func aiPaddleDeflectsIncomingBall() {
        var engine = playingEngine(
            ball: CGPoint(x: 178, y: 100),
            velocity: CGVector(dx: 120, dy: 0)
        )
        engine.aiPaddleY = 100
        engine.step(dt: 0.04)
        #expect(engine.ballVelocity.dx < 0)
        #expect(engine.lastEvent == .paddle)
    }

    @Test func ballPastLeftEdgeAwardsAIPoint() {
        var engine = playingEngine(
            ball: CGPoint(x: -8, y: 100),
            velocity: CGVector(dx: -80, dy: 0)
        )
        engine.step(dt: 0.02)
        #expect(engine.aiScore == 1)
        #expect(engine.playerScore == 0)
        #expect(engine.phase == .serving)
        #expect(engine.lastEvent == .scored(byPlayer: false))
    }

    @Test func ballPastRightEdgeAwardsPlayerPoint() {
        var engine = playingEngine(
            ball: CGPoint(x: 208, y: 100),
            velocity: CGVector(dx: 80, dy: 0)
        )
        engine.step(dt: 0.02)
        #expect(engine.playerScore == 1)
        #expect(engine.aiScore == 0)
        #expect(engine.lastEvent == .scored(byPlayer: true))
    }

    @Test func serveNeverHasZeroHorizontalSpeed() {
        var engine = PongEngine(courtSize: court, opponent: TrackingOpponent())
        for _ in 0..<20 {
            engine.prepareServe(towardPlayer: Bool.random())
            engine.launchServe()
            #expect(abs(engine.ballVelocity.dx) >= 50)
            #expect(engine.phase == .playing)
        }
    }

    @Test func paddleHitIncreasesSpeedUpToCap() {
        var engine = playingEngine(
            ball: CGPoint(x: 22, y: 100),
            velocity: CGVector(dx: -125, dy: 0)
        )
        engine.playerPaddleY = 100
        let before = engine.ballSpeed
        engine.step(dt: 0.04)
        #expect(engine.ballSpeed > before)
        #expect(engine.ballSpeed <= PongEngine.maxBallSpeed)
    }

    @Test func aiMovesTowardIncomingBall() {
        var engine = playingEngine(
            ball: CGPoint(x: 80, y: 40),
            velocity: CGVector(dx: 90, dy: 0)
        )
        engine.aiPaddleY = 160
        let start = engine.aiPaddleY
        engine.step(dt: 0.2)
        #expect(engine.aiPaddleY < start)
    }

    @Test func resetMatchClearsScoresAndServes() {
        var engine = playingEngine(ball: CGPoint(x: 100, y: 100), velocity: CGVector(dx: 40, dy: 10))
        engine.step(dt: 1)
        engine.resetMatch()
        #expect(engine.playerScore == 0)
        #expect(engine.aiScore == 0)
        #expect(engine.phase == .serving)
        #expect(engine.ballVelocity == .zero)
    }

    @Test func trailRecordsRecentBallPositions() {
        var engine = playingEngine(
            ball: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 40, dy: 10)
        )
        for _ in 0..<20 {
            engine.step(dt: 1.0 / 30.0)
        }
        #expect(!engine.trail.isEmpty)
        #expect(engine.trail.count <= engine.metrics.trailLength)
    }

    private func playingEngine(ball: CGPoint, velocity: CGVector) -> PongEngine {
        var engine = PongEngine(courtSize: court, opponent: TrackingOpponent())
        engine.playerPaddleY = 100
        engine.aiPaddleY = 100
        engine.prepareServe(towardPlayer: false)
        engine.launchServe()
        engine.placeBall(at: ball, velocity: velocity)
        return engine
    }
}

private struct StubPredictor: PongMLPredicting {
    let value: Double

    func predict(
        ballX: Double,
        ballY: Double,
        velX: Double,
        velY: Double,
        paddleY: Double,
        courtWidth: Double,
        courtHeight: Double
    ) -> Double? {
        value
    }
}
