//
//  PongGame.swift
//  iPong
//
//  Created by Kannan Sekar Annu Radha on 18/09/2024.
//

import Foundation
import SwiftUI
import Combine
import WatchKit

class PongGame: ObservableObject {
    // Screen dimensions
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    // Paddle properties
    @Published var playerPaddlePosition: CGFloat = 85
    @Published var aiPaddlePosition: CGFloat = 85

    // AI Paddle X Position (fixed)
    var aiPaddleXPosition: CGFloat {
        screenWidth - 20
    }

    // Ball properties
    @Published var ballPosition: CGPoint = CGPoint(x: 68, y: 85)
    private var ballVelocity: CGVector = CGVector(dx: 2, dy: 2)

    // Scores
    @Published var playerScore: Int = 0
    @Published var aiScore: Int = 0

    // Timer
    private var gameTimer: AnyCancellable?

    // Paddle movement speed for AI
    private let paddleSpeed: CGFloat = 5

    // Initialization
    init() {
        // Dynamically obtain screen dimensions
        let screen = WKInterfaceDevice.current().screenBounds
        screenWidth = screen.width
        screenHeight = screen.height
        resetGame()
    }

    func startGame() {
        // Start game loop
        gameTimer = Timer.publish(every: 0.016, on: .main, in: .common) // ~60 FPS
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateGame()
            }
    }

    func resetGame() {
        // Initialize positions
        playerPaddlePosition = screenHeight / 2
        aiPaddlePosition = screenHeight / 2
        ballPosition = CGPoint(x: screenWidth / 2, y: screenHeight / 2)
        ballVelocity = CGVector(dx: Double.random(in: -2...2), dy: Double.random(in: -2...2))
        playerScore = 0
        aiScore = 0
    }

    func updateGame() {
        // Update ball position
        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy

        // Collision with top and bottom walls
        if ballPosition.y <= 5 || ballPosition.y >= screenHeight - 5 {
            ballVelocity.dy *= -1
            // Determine direction for haptic feedback
            let hapticType: WKHapticType = ballVelocity.dy > 0 ? .directionDown : .directionUp
            playHapticFeedback(hapticType)
            print("Ball collided with wall. New dy: \(ballVelocity.dy)")
        }

        // Collision with player paddle
        if ballPosition.x <= 25, abs(ballPosition.y - playerPaddlePosition) <= 30 {
            ballVelocity.dx *= -1
            playHapticFeedback(.click)
            print("Ball hit Player Paddle")
        }

        // Collision with AI paddle
        if ballPosition.x >= screenWidth - 25, abs(ballPosition.y - aiPaddlePosition) <= 30 {
            ballVelocity.dx *= -1
            playHapticFeedback(.click)
            print("Ball hit AI Paddle")
        }

        // Check for scoring
        if ballPosition.x < 0 {
            aiScore += 1
            playHapticFeedback(.success)
            print("AI Scores! AI: \(aiScore)")
            resetBall(direction: .right)
        } else if ballPosition.x > screenWidth {
            playerScore += 1
            playHapticFeedback(.success)
            print("Player Scores! Player: \(playerScore)")
            resetBall(direction: .left)
        }

        // Update AI paddle
        updateAIPaddle()
    }

    enum BallDirection {
        case left
        case right
    }

    func resetBall(direction: BallDirection) {
        ballPosition = CGPoint(x: screenWidth / 2, y: screenHeight / 2)
        // Reset velocity with direction
        ballVelocity = CGVector(dx: direction == .left ? -2 : 2, dy: Double.random(in: -2...2))
        // Determine direction for haptic feedback
        let hapticType: WKHapticType = direction == .left ? .directionUp : .directionDown
        playHapticFeedback(hapticType)
        print("Ball reset. Direction: \(direction), New Velocity: \(ballVelocity)")
    }

    func updateAIPaddle() {
        // Simple AI: move towards the ball's y position
        let target = ballPosition.y
        if aiPaddlePosition < target {
            aiPaddlePosition += paddleSpeed
        } else if aiPaddlePosition > target {
            aiPaddlePosition -= paddleSpeed
        }
        // Clamp position
        aiPaddlePosition = max(30, min(screenHeight - 30, aiPaddlePosition))
        print("AI Paddle Position Updated: \(aiPaddlePosition)")
    }

    func playHapticFeedback(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
