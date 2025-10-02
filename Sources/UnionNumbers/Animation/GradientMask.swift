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
    
    public init (_ size: CGFloat) {
        self.size = size
    }
    
    var body: some View {
        VStack(
            spacing: 0
        ) {
            gradient(start: .top, end: .bottom)
            Color.white
            gradient(start: .bottom, end: .top)
        }
        
    }
    
    @ViewBuilder
    private func gradient(start: UnitPoint, end: UnitPoint) -> some View {
        SmoothGradient(
            colors: [
                Color.white.opacity(0),
                Color.white
            ],
            startPoint: start,
            endPoint: end,
            smoothType: .smootherstep
        )
        .frame(height: size)
    }
}
