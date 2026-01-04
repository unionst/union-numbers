//
//  DigitView.swift
//  union-numbers
//
//  Created by Vitor Lelis on 8/12/25.
//

import SwiftUI

/// A view that displays a single animated digit with appropriate transitions.
struct DigitView: View {

    // MARK: - Properties

    let digit: AnimatedDigit
    let oldDigit: AnimatedDigit?
    let fontSize: CGFloat
    let isTransitioningFromZero: Bool
    let isTransitioningToZero: Bool
    let isAddingDecimal: Bool
    let isDeletingDecimal: Bool
    let isIncreasing: Bool
    let overallOpacity: Double

    // MARK: - Body

    var body: some View {
        Text(String(digit.char))
            .opacity(computedOpacity)
            .contentTransition(.identity)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: fontSize)
            .transition(transition)
    }

    // MARK: - Computed Properties

    private var computedOpacity: Double {
        if digit.isPlaceholder && digit.digitIndex == 0 && digit.char == "0" {
            return overallOpacity
        }
        if digit.isPlaceholder {
            return 0.1
        }
        return overallOpacity
    }

    private var transition: AnyTransition {
        // Special handling for separators
        if digit.char == "," {
            return AnyTransition.opacity.animation(AnimationTiming.Spring.commaFade)
        }

        if digit.char == "." {
            return .opacity
        }

        let offset = AnimationTiming.fontOffset(for: fontSize)

        // Placeholder transitions
        if digit.isPlaceholder {
            return placeholderTransition(offset: offset)
        }

        // Zero transition handling
        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && digit.char == "0" {
            return .asymmetric(
                insertion: .offset(y: -offset).combined(with: .opacity),
                removal: .offset(y: offset).combined(with: .opacity)
            )
        }

        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && !digit.isNew {
            return .asymmetric(
                insertion: .offset(y: offset).combined(with: .opacity),
                removal: .offset(y: offset).combined(with: .opacity)
            )
        }

        // Standard digit transition (ticker style)
        // Increasing (1→2): old exits UP, new enters from BELOW
        // Decreasing (2→1): old exits DOWN, new enters from ABOVE
        if isIncreasing {
            return .asymmetric(
                insertion: .offset(y: offset).combined(with: .opacity),   // from below
                removal: .offset(y: -offset).combined(with: .opacity)     // to above
            )
        } else {
            return .asymmetric(
                insertion: .offset(y: -offset).combined(with: .opacity),  // from above
                removal: .offset(y: offset).combined(with: .opacity)      // to below
            )
        }
    }

    private func placeholderTransition(offset: CGFloat) -> AnyTransition {
        let insertionTransition: AnyTransition
        let removalTransition: AnyTransition

        if isAddingDecimal {
            insertionTransition = .offset(y: offset).combined(with: .opacity)
        } else {
            insertionTransition = .offset(y: -offset).combined(with: .opacity)
        }

        if isDeletingDecimal {
            removalTransition = .offset(y: offset).combined(with: .opacity)
        } else {
            removalTransition = .offset(y: -offset).combined(with: .opacity)
        }

        return .asymmetric(insertion: insertionTransition, removal: removalTransition)
    }

}
