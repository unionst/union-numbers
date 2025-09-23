//
//  GradientMask.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 13/08/25.
//
import SwiftUI
import UnionGradients

struct GradientMask: View {
    var size: CGFloat
    
    public init (
        _ size: CGFloat
    ) {
        self.size = size
    }
    
    var body: some View {
        VStack(
            spacing: 0
        ) {
            SmoothGradient(
                colors: [
                    Color.white
                        .opacity(
                            0
                        ),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom,
                smoothType: .smootherstep
            )
            .frame(
                height: size
            )
            
            Color.white
            
            SmoothGradient(
                colors: [
                    Color.white
                        .opacity(
                        0
                    ),
                    Color.white
                ],
                startPoint: .bottom,
                endPoint: .top,
                smoothType: .smootherstep
            )
            .frame(
                height: size
            )
        }

    }
}
