import SwiftUI

struct CourtView: View {
    var metrics: PongMetrics
    var playerY: CGFloat
    var aiY: CGFloat
    var ball: CGPoint
    var trail: [CGPoint]
    var isServing: Bool

    var body: some View {
        Canvas { context, size in
            drawCourt(context: &context, size: size)
            drawTrail(context: &context)
            drawPaddle(context: &context, x: metrics.playerPaddleX, y: playerY)
            drawPaddle(context: &context, x: metrics.aiPaddleX, y: aiY)
            drawBall(context: &context)
        }
    }

    private func drawCourt(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(GamePalette.court))

        var net = Path()
        net.move(to: CGPoint(x: size.width / 2, y: 22))
        net.addLine(to: CGPoint(x: size.width / 2, y: size.height - 16))
        context.stroke(
            net,
            with: .color(GamePalette.line),
            style: StrokeStyle(lineWidth: 1.5, dash: [5, 6])
        )
    }

    private func drawTrail(context: inout GraphicsContext) {
        guard trail.count > 1 else { return }
        for (index, point) in trail.enumerated() {
            let progress = CGFloat(index + 1) / CGFloat(trail.count)
            let radius = metrics.ballRadius * (0.35 + progress * 0.55)
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(GamePalette.mint.opacity(0.12 + progress * 0.38))
            )
        }
    }

    private func drawPaddle(context: inout GraphicsContext, x: CGFloat, y: CGFloat) {
        let rect = metrics.paddleRect(x: x, y: y)
        let path = Path(roundedRect: rect, cornerRadius: 2.5)
        context.fill(path, with: .color(GamePalette.cream))
        var highlight = rect
        highlight.size.width = 2
        context.fill(
            Path(roundedRect: highlight, cornerRadius: 1),
            with: .color(.white.opacity(0.28))
        )
    }

    private func drawBall(context: inout GraphicsContext) {
        let radius = metrics.ballRadius
        let glowRadius = radius * (isServing ? 3.2 : 2.4)
        let glowRect = CGRect(
            x: ball.x - glowRadius,
            y: ball.y - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        )
        context.fill(Path(ellipseIn: glowRect), with: .color(GamePalette.mint.opacity(0.22)))

        var glowing = context
        glowing.addFilter(.shadow(color: GamePalette.mint.opacity(0.95), radius: 6))
        let ballRect = CGRect(
            x: ball.x - radius,
            y: ball.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        glowing.fill(Path(ellipseIn: ballRect), with: .color(GamePalette.mint))

        let spec = CGRect(
            x: ball.x - radius * 0.45,
            y: ball.y - radius * 0.55,
            width: radius * 0.7,
            height: radius * 0.55
        )
        context.fill(Path(ellipseIn: spec), with: .color(.white.opacity(0.55)))
    }
}

struct GameHUD: View {
    var playerScore: Int
    var aiScore: Int
    var onReset: () -> Void = {}

    var body: some View {
        VStack(spacing: 2) {
            Text("iPONG")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .kerning(3)
                .foregroundStyle(GamePalette.cream)
                .accessibilityIdentifier("iPONG")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Long press to reset the match.")
                .onLongPressGesture(minimumDuration: 0.8, perform: onReset)

            HStack {
                Text("\(playerScore)")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("playerScore")
                Text("\(aiScore)")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("aiScore")
            }
            .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(GamePalette.score)
            .allowsHitTesting(false)
        }
        .padding(.top, 1)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
