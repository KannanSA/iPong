import SwiftUI

struct ContentView: View {
    @State private var game = PongGame()
    @FocusState private var crownFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .top) {
                GamePalette.court.ignoresSafeArea()

                CourtView(
                    metrics: game.metrics,
                    playerY: game.playerPaddleY,
                    aiY: game.aiPaddleY,
                    ball: game.ballPosition,
                    trail: game.trail,
                    isServing: game.phase == .serving
                )
                .contentShape(Rectangle())
                .gesture(paddleGesture)

                GameHUD(
                    playerScore: game.playerScore,
                    aiScore: game.aiScore,
                    onReset: { game.resetMatch() }
                )
            }
            .onAppear {
                game.resize(to: size)
                game.start()
                crownFocused = true
            }
            .onChange(of: size) { _, newSize in
                game.resize(to: newSize)
            }
        }
        .ignoresSafeArea()
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation(
            crownBinding,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: 0.5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, phase in
            game.handleScenePhase(phase)
            if phase == .active {
                crownFocused = true
            }
        }
        .onAppear {
            crownFocused = true
        }
        .accessibilityLabel("iPong. Digital Crown or drag to move your paddle.")
    }

    private var crownRange: ClosedRange<Double> {
        let minY = Double(game.paddleMinY)
        let maxY = Double(game.paddleMaxY)
        return minY < maxY ? minY...maxY : 0...1
    }

    private var crownBinding: Binding<Double> {
        Binding(
            get: { Double(game.playerPaddleY) },
            set: { game.playerPaddleY = CGFloat($0) }
        )
    }

    private var paddleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                game.playerPaddleY = value.location.y
                crownFocused = true
            }
    }
}

#Preview {
    ContentView()
}
