//
//  AnimationTiming.swift
//  union-numbers
//
//  Created by Vitor Lelis on 8/12/25.
//

import SwiftUI

/// Animation timing configuration for number transitions.
enum AnimationTiming {

    // MARK: - Debounce

    enum Debounce {
        static let deletion: Double = 0.015
        static let shortInput: Double = 0.025
        static let longInput: Double = 0.04
    }

    // MARK: - Fade

    enum Fade {
        static let duration: Double = 0.15
        static let gap: Double = 0.05
        static var total: Double { duration * 2 + gap }
    }

    // MARK: - Spring Animations

    enum Spring {
        static let standard = Animation.interactiveSpring(
            response: 0.25,
            dampingFraction: 0.85,
            blendDuration: 0.15
        )

        static let removal = Animation.interactiveSpring(
            response: 0.3,
            dampingFraction: 0.9,
            blendDuration: 0.1
        )

        static let fast = Animation.interactiveSpring(
            response: 0.15,
            dampingFraction: 0.9,
            blendDuration: 0.1
        )

        static let commaFade = Animation.spring(duration: 0.1)
    }

    // MARK: - Transition Reset

    static var transitionReset: Double { Fade.total + 0.05 }

    // MARK: - Font Offset

    static func fontOffset(for fontSize: CGFloat) -> CGFloat {
        fontSize * 2.0
    }
}
