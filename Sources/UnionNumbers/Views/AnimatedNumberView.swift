//
//  AnimatedNumberView.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import SwiftUI
import UnionShake

/// The internal view that renders animated digits with transitions.
@available(macOS 14.0, iOS 17.0, *)
struct AnimatedNumberView: View {

    // MARK: - Properties

    let digits: [AnimatedDigit]
    let oldDigits: [Int: AnimatedDigit]
    let fontSize: CGFloat
    let isTransitioningFromZero: Bool
    let isTransitioningToZero: Bool
    let isAddingDecimal: Bool
    let isDeletingDecimal: Bool
    let isIncreasing: Bool
    let scale: CGFloat
    let shakeCounter: Int
    let onContentWidthChange: (CGFloat) -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            ForEach(digits, id: \.id) { digit in
                DigitView(
                    digit: digit,
                    oldDigit: oldDigits[digit.digitIndex],
                    fontSize: fontSize,
                    isTransitioningFromZero: isTransitioningFromZero,
                    isTransitioningToZero: isTransitioningToZero,
                    isAddingDecimal: isAddingDecimal,
                    isDeletingDecimal: isDeletingDecimal,
                    isIncreasing: isIncreasing,
                    overallOpacity: 1.0
                )
                .fixedSize()
                .zIndex(zIndex(for: digit))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(contentWidthReader)
        .scaleEffect(scale)
        .animation(AnimationTiming.Spring.standard, value: scale)
        .padding(.vertical, fontSize * 2)
        .padding(.horizontal, fontSize)
        .mask(GradientMask(padding: fontSize * 2, fade: fontSize * 0.15))
        .padding(.vertical, -fontSize * 2)
        .padding(.horizontal, -fontSize)
        .shake(on: shakeCounter, amount: 8, shakesPerUnit: 3)
    }

    // MARK: - Private Views

    private var contentWidthReader: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    onContentWidthChange(geometry.size.width)
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    onContentWidthChange(newWidth)
                }
                .onChange(of: digits.map(\.id)) { _, _ in
                    onContentWidthChange(geometry.size.width)
                }
        }
    }

    // MARK: - Private Helpers

    private func zIndex(for digit: AnimatedDigit) -> Double {
        guard digit.char != "," else { return 0 }

        if isTransitioningFromZero {
            return (!digit.isNew && digit.char == "0") ? 3 : 2
        }

        if isTransitioningToZero {
            return (digit.isNew && digit.char == "0") ? 3 : 2
        }

        return digit.isNew ? 2 : 1
    }
}
