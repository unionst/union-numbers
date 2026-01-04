//
//  NumberAnimationModel.swift
//  union-numbers
//
//  Created by Vitor Lelis on 8/12/25.
//

import Foundation
import SwiftUI

// MARK: - NumberAnimationModel

/// Observable model that manages the animated digit state for number transitions.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
final class NumberAnimationModel {

    // MARK: - Public State

    private(set) var digits: [AnimatedDigit] = []
    private(set) var oldDigits: [Int: AnimatedDigit] = [:]
    private(set) var isTransitioningFromZero = false
    private(set) var isTransitioningToZero = false
    private(set) var isAnimating = false
    private(set) var isAddingDecimal = false
    private(set) var isDeletingDecimal = false
    private(set) var isIncreasing = true

    // MARK: - Private Properties

    private let queue = AnimationQueue()
    private var currentValue = ""
    private var currentRawValue: Double = 0
    private var previousDigits: [AnimatedDigit] = []
    private var isInitialLoad = true

    // MARK: - Public Methods

    /// Updates the displayed value with animation.
    /// - Parameters:
    ///   - formattedValue: The pre-formatted string to display.
    ///   - rawValue: The raw numeric value for determining animation direction.
    func setValue(_ formattedValue: String, rawValue: Double) {
        Task { @MainActor in
            if isInitialLoad {
                await applyValue(formattedValue, rawValue: rawValue)
                return
            }

            await queue.enqueue(formattedValue) { @MainActor [weak self] value in
                guard let self else { return }
                await self.applyValue(value, rawValue: rawValue)
            }
        }
    }

    // MARK: - Private Methods

    @discardableResult
    private func applyValue(_ formattedValue: String, rawValue: Double) async -> Bool {
        let oldValue = currentValue
        let oldRawValue = currentRawValue

        currentValue = formattedValue
        currentRawValue = rawValue

        // Update transition flags based on raw numeric values
        isTransitioningFromZero = oldRawValue == 0 && rawValue > 0
        isTransitioningToZero = oldRawValue > 0 && rawValue == 0
        isIncreasing = rawValue >= oldRawValue

        // Check for decimal changes in the formatted string
        let oldHasDecimal = oldValue.contains(".")
        let newHasDecimal = formattedValue.contains(".")
        isAddingDecimal = !oldHasDecimal && newHasDecimal
        isDeletingDecimal = oldHasDecimal && !newHasDecimal

        let isRemovingDigit = formattedValue.count < oldValue.count
        let newDigits = createDigitsFromFormatted(
            formattedValue,
            oldFormatted: oldValue,
            isIncreasing: rawValue > oldRawValue
        )

        renderDigits(newDigits: newDigits, isRemovingDigit: isRemovingDigit)
        previousDigits = newDigits

        if !isInitialLoad {
            scheduleResetFlags()
        }

        return true
    }

    private func renderDigits(newDigits: [AnimatedDigit], isRemovingDigit: Bool) {
        if isInitialLoad {
            oldDigits = digits.reduce(into: [:]) { $0[$1.digitIndex] = $1 }
            digits = newDigits
            isInitialLoad = false
        } else {
            isAnimating = true
            let animation = isRemovingDigit
                ? AnimationTiming.Spring.removal
                : AnimationTiming.Spring.standard

            withAnimation(animation) {
                oldDigits = digits.reduce(into: [:]) { $0[$1.digitIndex] = $1 }
                digits = newDigits
            }
        }
    }

    private func scheduleResetFlags() {
        Task {
            try? await Task.sleep(for: .seconds(AnimationTiming.transitionReset))
            isTransitioningFromZero = false
            isTransitioningToZero = false
            isAnimating = false
            isAddingDecimal = false
            isDeletingDecimal = false
        }
    }

    // MARK: - Digit Creation

    /// Creates animated digits from a formatted string.
    private func createDigitsFromFormatted(
        _ formatted: String,
        oldFormatted: String,
        isIncreasing: Bool
    ) -> [AnimatedDigit] {
        var result: [AnimatedDigit] = []
        var digitPosition = 0

        // Build a map of previous digit positions for identity tracking
        var previousPositionMap: [Int: AnimatedDigit] = [:]
        for digit in previousDigits {
            previousPositionMap[digit.digitIndex] = digit
        }

        for (index, char) in formatted.enumerated() {
            let isNew = !isInitialLoad && (index >= oldFormatted.count ||
                (index < oldFormatted.count && char != oldFormatted[oldFormatted.index(oldFormatted.startIndex, offsetBy: index)]))

            result.append(AnimatedDigit(
                char: char,
                digitIndex: digitPosition,
                isNew: isNew,
                isZeroTransition: isTransitioningToZero && char == "0"
            ))
            digitPosition += 1
        }

        return result
    }
}
