//
//  GradientMask.swift
//  union-numbers
//
//  Created by Vitor Lelis on 13/08/25.
//

import SwiftUI
import UnionGradients

/// A gradient mask that fades content at the top and bottom edges.
struct GradientMask: View {

    // MARK: - Properties

    let size: CGFloat

    // MARK: - Initialization

    init(_ size: CGFloat) {
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            gradient(from: .top, to: .bottom)
            Color.white
            gradient(from: .bottom, to: .top)
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func gradient(from start: UnitPoint, to end: UnitPoint) -> some View {
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
