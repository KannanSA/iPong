//
//  ContentView.swift
//  iPong Watch App
//
//  Created by Kannan Sekar Annu Radha on 18/09/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject var game = PongGame()

    var body: some View {
        ZStack {
            // Background
            Color.black
                .edgesIgnoringSafeArea(.all)

            // Middle Line
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 2, height: 200)
                Spacer()
            }

            // Player Paddle (Player 0) - Controlled by Touch
            PlayerPaddleView(paddlePosition: $game.playerPaddlePosition, screenHeight: game.screenHeight)

            // AI Paddle
            Rectangle()
                .fill(Color.red)
                .frame(width: 10, height: 60)
                .position(x: game.aiPaddleXPosition, y: game.aiPaddlePosition)

            // Ball
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .position(x: game.ballPosition.x, y: game.ballPosition.y)

            // Score Display
            VStack {
                Text("Player: \(game.playerScore)")
                    .foregroundColor(.white)
                Text("AI: \(game.aiScore)")
                    .foregroundColor(.white)
            }
            .position(x: game.screenWidth / 2, y: 10) // Center top
        }
        .onAppear {
            game.startGame()
        }
    }
}
