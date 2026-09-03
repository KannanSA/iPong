import CoreGraphics
import Foundation

enum PongPhase: Equatable {
    case serving
    case playing
}

enum PongEvent: Equatable {
    case wall
    case paddle
    case scored(byPlayer: Bool)
}

struct PongSnapshot: Equatable {
    var courtSize: CGSize
    var ballPosition: CGPoint
    var ballVelocity: CGVector
    var playerPaddleY: CGFloat
    var aiPaddleY: CGFloat
}

struct PongMetrics: Equatable {
    var courtSize: CGSize

    var paddleWidth: CGFloat { 8 }
    var paddleHeight: CGFloat {
        min(max(courtSize.height * 0.28, 42), 64)
    }

    var ballRadius: CGFloat { 5.5 }
    var sideInset: CGFloat { 16 }
    var trailLength: Int { 12 }

    var playerPaddleX: CGFloat { sideInset + paddleWidth / 2 }
    var aiPaddleX: CGFloat { courtSize.width - sideInset - paddleWidth / 2 }

    var minPaddleY: CGFloat { paddleHeight / 2 + 6 }
    var maxPaddleY: CGFloat { max(minPaddleY, courtSize.height - paddleHeight / 2 - 6) }

    func clampPaddleY(_ y: CGFloat) -> CGFloat {
        min(max(y, minPaddleY), maxPaddleY)
    }

    func paddleRect(x: CGFloat, y: CGFloat) -> CGRect {
        CGRect(
            x: x - paddleWidth / 2,
            y: y - paddleHeight / 2,
            width: paddleWidth,
            height: paddleHeight
        )
    }
}

struct PongEngine {
    static let baseBallSpeed: CGFloat = 125
    static let maxBallSpeed: CGFloat = 220
    static let speedGain: CGFloat = 1.06
    static let serveDelay: TimeInterval = 0.7
    static let aiMaxSpeed: CGFloat = 96

    private(set) var metrics: PongMetrics
    var playerPaddleY: CGFloat
    var aiPaddleY: CGFloat
    private(set) var ballPosition: CGPoint
    private(set) var ballVelocity: CGVector
    private(set) var playerScore: Int
    private(set) var aiScore: Int
    private(set) var trail: [CGPoint]
    private(set) var phase: PongPhase
    private(set) var lastEvent: PongEvent?

    private var serveCooldown: TimeInterval
    private var serveTowardPlayer: Bool
    private let opponent: any OpponentControlling

    var snapshot: PongSnapshot {
        PongSnapshot(
            courtSize: metrics.courtSize,
            ballPosition: ballPosition,
            ballVelocity: ballVelocity,
            playerPaddleY: playerPaddleY,
            aiPaddleY: aiPaddleY
        )
    }

    var ballSpeed: CGFloat {
        hypot(ballVelocity.dx, ballVelocity.dy)
    }

    init(
        courtSize: CGSize = CGSize(width: 198, height: 242),
        opponent: any OpponentControlling = CoreMLOpponent()
    ) {
        self.metrics = PongMetrics(courtSize: courtSize)
        self.opponent = opponent
        let midY = max(courtSize.height / 2, 1)
        self.playerPaddleY = midY
        self.aiPaddleY = midY
        self.ballPosition = CGPoint(x: max(courtSize.width / 2, 1), y: midY)
        self.ballVelocity = .zero
        self.playerScore = 0
        self.aiScore = 0
        self.trail = []
        self.phase = .serving
        self.lastEvent = nil
        self.serveCooldown = 0.4
        self.serveTowardPlayer = false
    }

    mutating func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let old = metrics.courtSize
        metrics.courtSize = size
        if old.width > 1, old.height > 1 {
            let sx = size.width / old.width
            let sy = size.height / old.height
            playerPaddleY *= sy
            aiPaddleY *= sy
            ballPosition = CGPoint(x: ballPosition.x * sx, y: ballPosition.y * sy)
            trail = trail.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
        }
        playerPaddleY = metrics.clampPaddleY(playerPaddleY)
        aiPaddleY = metrics.clampPaddleY(aiPaddleY)
    }

    mutating func setPlayerPaddleY(_ y: CGFloat) {
        playerPaddleY = metrics.clampPaddleY(y)
    }

    mutating func placeBall(at position: CGPoint, velocity: CGVector) {
        ballPosition = position
        ballVelocity = velocity
        phase = .playing
        trail = []
    }

    mutating func resetMatch() {
        playerScore = 0
        aiScore = 0
        playerPaddleY = metrics.clampPaddleY(metrics.courtSize.height / 2)
        aiPaddleY = playerPaddleY
        prepareServe(towardPlayer: Bool.random())
    }

    mutating func step(dt: TimeInterval) {
        lastEvent = nil
        let dt = max(0, min(dt, 1.0 / 15.0))
        guard dt > 0 else { return }

        switch phase {
        case .serving:
            serveCooldown -= dt
            if serveCooldown <= 0 {
                launchServe()
            }
        case .playing:
            integrateBall(dt: dt)
            recordTrail()
            resolveWalls()
            resolvePaddles()
            resolveScore()
        }

        moveAI(dt: dt)
    }

    mutating func prepareServe(towardPlayer: Bool) {
        phase = .serving
        serveTowardPlayer = towardPlayer
        serveCooldown = Self.serveDelay
        trail = []
        ballPosition = CGPoint(
            x: metrics.courtSize.width / 2,
            y: metrics.courtSize.height / 2
        )
        ballVelocity = .zero
    }

    mutating func launchServe() {
        let direction: CGFloat = serveTowardPlayer ? -1 : 1
        let angle = CGFloat.random(in: -0.38...0.38)
        var velocity = CGVector(
            dx: cos(angle) * Self.baseBallSpeed * direction,
            dy: sin(angle) * Self.baseBallSpeed
        )
        if abs(velocity.dx) < 50 {
            velocity.dx = 90 * direction
        }
        ballVelocity = velocity
        phase = .playing
    }

    private mutating func integrateBall(dt: TimeInterval) {
        ballPosition.x += ballVelocity.dx * CGFloat(dt)
        ballPosition.y += ballVelocity.dy * CGFloat(dt)
    }

    private mutating func recordTrail() {
        trail.append(ballPosition)
        let extra = trail.count - metrics.trailLength
        if extra > 0 {
            trail.removeFirst(extra)
        }
    }

    private mutating func resolveWalls() {
        let radius = metrics.ballRadius
        let minY = radius
        let maxY = metrics.courtSize.height - radius

        if ballPosition.y <= minY {
            ballPosition.y = minY
            if ballVelocity.dy < 0 {
                ballVelocity.dy *= -1
                lastEvent = .wall
            }
        } else if ballPosition.y >= maxY {
            ballPosition.y = maxY
            if ballVelocity.dy > 0 {
                ballVelocity.dy *= -1
                lastEvent = .wall
            }
        }
    }

    private mutating func resolvePaddles() {
        let radius = metrics.ballRadius
        let ballRect = CGRect(
            x: ballPosition.x - radius,
            y: ballPosition.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let playerRect = metrics.paddleRect(x: metrics.playerPaddleX, y: playerPaddleY)
            .insetBy(dx: -1.5, dy: -1)
        if ballVelocity.dx < 0, ballRect.intersects(playerRect) {
            deflect(fromPlayer: true)
            return
        }

        let aiRect = metrics.paddleRect(x: metrics.aiPaddleX, y: aiPaddleY)
            .insetBy(dx: -1.5, dy: -1)
        if ballVelocity.dx > 0, ballRect.intersects(aiRect) {
            deflect(fromPlayer: false)
        }
    }

    private mutating func deflect(fromPlayer: Bool) {
        let paddleY = fromPlayer ? playerPaddleY : aiPaddleY
        let half = metrics.paddleHeight / 2
        let relative = max(-1, min(1, (ballPosition.y - paddleY) / half))
        let speed = min(max(ballSpeed, Self.baseBallSpeed) * Self.speedGain, Self.maxBallSpeed)
        let angle = relative * .pi * 0.32
        let direction: CGFloat = fromPlayer ? 1 : -1
        ballVelocity = CGVector(
            dx: cos(angle) * speed * direction,
            dy: sin(angle) * speed
        )

        let clearance = metrics.paddleWidth / 2 + metrics.ballRadius + 0.5
        if fromPlayer {
            ballPosition.x = metrics.playerPaddleX + clearance
        } else {
            ballPosition.x = metrics.aiPaddleX - clearance
        }
        lastEvent = .paddle
    }

    private mutating func resolveScore() {
        let radius = metrics.ballRadius
        if ballPosition.x < -radius {
            aiScore += 1
            lastEvent = .scored(byPlayer: false)
            prepareServe(towardPlayer: true)
        } else if ballPosition.x > metrics.courtSize.width + radius {
            playerScore += 1
            lastEvent = .scored(byPlayer: true)
            prepareServe(towardPlayer: false)
        }
    }

    private mutating func moveAI(dt: TimeInterval) {
        let target = opponent.desiredPaddleY(
            snapshot: snapshot,
            dt: dt,
            metrics: metrics
        )
        let delta = target - aiPaddleY
        let maxStep = Self.aiMaxSpeed * CGFloat(dt)
        if abs(delta) <= maxStep {
            aiPaddleY = metrics.clampPaddleY(target)
        } else {
            aiPaddleY = metrics.clampPaddleY(aiPaddleY + maxStep * (delta > 0 ? 1 : -1))
        }
    }
}
