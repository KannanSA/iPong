//
//  PlayerPaddleView.swift
//  iPong
//
//  Created by Kannan Sekar Annu Radha on 18/09/2024.
//

import SwiftUI

struct PlayerPaddleView: View {
    @Binding var paddlePosition: CGFloat
    @State private var dragOffset: CGFloat = 0.0

    let screenHeight: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.green)
            .frame(width: 10, height: 60)
            .position(x: 20, y: paddlePosition + dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Calculate the new position based on drag
                        let newOffset = value.translation.height
                        let tentativePosition = paddlePosition + newOffset

                        // Clamp the paddle within screen bounds
                        if tentativePosition >= 30 && tentativePosition <= screenHeight - 30 {
                            dragOffset = newOffset
                        }
                    }
                    .onEnded { value in
                        // Update the paddle's position and reset the drag offset
                        let newOffset = value.translation.height
                        let tentativePosition = paddlePosition + newOffset

                        // Clamp the paddle within screen bounds
                        paddlePosition = max(30, min(screenHeight - 30, tentativePosition))
                        dragOffset = 0.0
                    }
            )
            .animation(.easeInOut(duration: 0.1), value: dragOffset)
    }
}
