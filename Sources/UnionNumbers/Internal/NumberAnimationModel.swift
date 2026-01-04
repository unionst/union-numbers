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
    ///
    /// Index strategy:
    /// - Integer digits: Left-anchored (0, 1, 2...) so leading digits stay stable when typing
    /// - Decimal separator: Fixed at -1
    /// - Fractional digits: Right-anchored from decimal (-2, -3...)
    /// - Grouping separators & symbols: Position-based offset (1000+)
    private func createDigitsFromFormatted(
        _ formatted: String,
        oldFormatted: String,
        isIncreasing: Bool
    ) -> [AnimatedDigit] {
        let oldCharsByIndex = Dictionary(
            uniqueKeysWithValues: previousDigits.map { ($0.digitIndex, $0.char) }
        )

        let chars = Array(formatted)
        let decimalIndex = findDecimalSeparatorIndex(in: chars)

        var result: [AnimatedDigit] = []
        var integerDigitCount = 0

        for (position, char) in chars.enumerated() {
            let index = semanticIndex(
                for: char,
                at: position,
                decimalIndex: decimalIndex,
                integerDigitCount: &integerDigitCount
            )

            result.append(AnimatedDigit(
                char: char,
                digitIndex: index,
                isNew: !isInitialLoad && oldCharsByIndex[index] != char,
                isZeroTransition: isTransitioningToZero && char == "0"
            ))
        }

        return result
    }

    /// Finds the decimal separator index, distinguishing it from grouping separators.
    /// The decimal separator is "." or "," followed by 1-2 digits at the end (typical for currency).
    /// Grouping separators are followed by exactly 3 digits and possibly more content.
    private func findDecimalSeparatorIndex(in chars: [Character]) -> Int? {
        var lastSeparatorIndex: Int?

        for (index, char) in chars.enumerated() {
            if char == "." || char == "," {
                lastSeparatorIndex = index
            }
        }

        guard let sepIndex = lastSeparatorIndex else {
            return nil
        }

        // Count digits after this separator
        let digitsAfter = chars.suffix(from: sepIndex + 1).filter { $0.isNumber }.count

        // If followed by exactly 3 digits, it's likely a grouping separator (thousands)
        // If followed by 1-2 digits, it's likely a decimal separator
        if digitsAfter == 3 {
            // Check if there are no more separators after - then it's a grouping separator
            let hasMoreSeparators = chars.suffix(from: sepIndex + 1).contains { $0 == "." || $0 == "," }
            if !hasMoreSeparators {
                return nil // It's a grouping separator, no decimal in this string
            }
        }

        // Check if this separator has digits before it (basic sanity check)
        let digitsBefore = chars.prefix(upTo: sepIndex).filter { $0.isNumber }.count
        if digitsBefore == 0 {
            return nil
        }

        return sepIndex
    }

    private func semanticIndex(
        for char: Character,
        at position: Int,
        decimalIndex: Int?,
        integerDigitCount: inout Int
    ) -> Int {
        if let decimalIndex, position == decimalIndex {
            return -1
        }
        if let decimalIndex, position > decimalIndex {
            return -(position - decimalIndex + 1)
        }
        if char.isNumber {
            defer { integerDigitCount += 1 }
            return integerDigitCount
        }
        return 1000 + position
    }
}
