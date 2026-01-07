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

    let paddingSize: CGFloat
    let fadeSize: CGFloat
    let enabled: Bool

    // MARK: - Initialization

    init(padding: CGFloat, fade: CGFloat, enabled: Bool = true) {
        self.paddingSize = padding
        self.fadeSize = fade
        self.enabled = enabled
    }

    // MARK: - Body

    var body: some View {
        if enabled {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: paddingSize - fadeSize)
                gradient(from: .top, to: .bottom)
                Color.white
                gradient(from: .bottom, to: .top)
                Color.clear
                    .frame(height: paddingSize - fadeSize)
            }
        } else {
            Color.white
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
        .frame(height: fadeSize)
    }
}
