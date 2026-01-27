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
    private var currentInputText: String?
    private var previousDigits: [AnimatedDigit] = []
    private var isInitialLoad = true

    // MARK: - Public Methods

    /// Updates the displayed value with animation.
    /// - Parameters:
    ///   - formattedValue: The pre-formatted string to display.
    ///   - rawValue: The raw numeric value for determining animation direction.
    ///   - inputText: Optional raw input text for placeholder detection.
    func setValue(_ formattedValue: String, rawValue: Double, inputText: String? = nil) {
        Task { @MainActor in
            if isInitialLoad {
                await applyValue(formattedValue, rawValue: rawValue, inputText: inputText)
                return
            }

            await queue.enqueue(formattedValue) { @MainActor [weak self] value in
                guard let self else { return }
                await self.applyValue(value, rawValue: rawValue, inputText: inputText)
            }
        }
    }

    // MARK: - Private Methods

    @discardableResult
    private func applyValue(_ formattedValue: String, rawValue: Double, inputText: String? = nil) async -> Bool {
        let oldValue = currentValue
        let oldRawValue = currentRawValue
        let oldInputText = currentInputText

        currentValue = formattedValue
        currentRawValue = rawValue
        currentInputText = inputText

        // Update transition flags based on raw numeric values
        isTransitioningFromZero = oldRawValue == 0 && rawValue > 0
        isTransitioningToZero = oldRawValue > 0 && rawValue == 0
        isIncreasing = rawValue >= oldRawValue

        // Check for decimal changes based on what's being shown
        // For string input, check if user just typed/deleted a decimal
        // For numeric input, check the formatted string
        let oldHasDecimal: Bool
        let newHasDecimal: Bool

        if inputText != nil {
            // String API: check if decimal is now being shown (user typed it)
            oldHasDecimal = oldInputText?.contains(".") ?? false
            newHasDecimal = inputText?.contains(".") ?? false
        } else {
            // Numeric API: check formatted string
            oldHasDecimal = oldValue.contains(".")
            newHasDecimal = formattedValue.contains(".")
        }

        isAddingDecimal = !oldHasDecimal && newHasDecimal
        isDeletingDecimal = oldHasDecimal && !newHasDecimal

        let isRemovingDigit = formattedValue.count < oldValue.count
        let newDigits = createDigitsFromFormatted(
            formattedValue,
            oldFormatted: oldValue,
            isIncreasing: rawValue > oldRawValue,
            inputText: inputText
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
        isIncreasing: Bool,
        inputText: String? = nil
    ) -> [AnimatedDigit] {
        let oldCharsByIndex = Dictionary(
            uniqueKeysWithValues: previousDigits.map { ($0.digitIndex, $0.char) }
        )

        let chars = Array(formatted)
        let decimalIndex = findDecimalSeparatorIndex(in: chars)

        // Check if user has typed a decimal point
        let inputHasDecimal = inputText?.contains(".") ?? true

        // Calculate how many fractional digits were typed
        let typedFractionalDigits = countTypedFractionalDigits(inputText)

        var result: [AnimatedDigit] = []
        var integerDigitCount = 0
        var fractionalDigitCount = 0

        for (position, char) in chars.enumerated() {
            let index = semanticIndex(
                for: char,
                at: position,
                decimalIndex: decimalIndex,
                integerDigitCount: &integerDigitCount
            )

            // Track fractional digit position for placeholder detection
            let isAfterDecimal = decimalIndex != nil && position > decimalIndex!
            let isDecimalSeparator = decimalIndex != nil && position == decimalIndex!

            if isAfterDecimal && char.isNumber {
                fractionalDigitCount += 1
            }

            // Hide decimal separator and fractional digits until user types decimal
            // But preserve currency symbols and other non-numeric characters
            if inputText != nil && !inputHasDecimal {
                if isDecimalSeparator {
                    continue
                }
                if isAfterDecimal && char.isNumber {
                    continue
                }
            }

            // A digit is a placeholder if:
            // - We have inputText (String-based API) AND either:
            //   - It's a fractional digit whose position exceeds what was typed
            //   - It's the zero shown when input is exactly "0" (empty state)
            //   - It's the currency symbol when input is "0" (empty state)
            let isFractionalPlaceholder = isAfterDecimal
                && char.isNumber
                && fractionalDigitCount > typedFractionalDigits

            let isEmptyState = inputText == "0"
            let isZeroPlaceholder = isEmptyState && char == "0" && index == 0
            let isCurrencyPlaceholder = isEmptyState && !char.isNumber && char != "," && char != "."

            let isPlaceholder = inputText != nil && (isFractionalPlaceholder || isZeroPlaceholder || isCurrencyPlaceholder)

            result.append(AnimatedDigit(
                char: char,
                digitIndex: index,
                isNew: !isInitialLoad && oldCharsByIndex[index] != char,
                isZeroTransition: isTransitioningToZero && char == "0",
                isPlaceholder: isPlaceholder
            ))
        }

        return result
    }

    /// Counts how many fractional digits were explicitly typed in the input.
    private func countTypedFractionalDigits(_ inputText: String?) -> Int {
        guard let input = inputText else { return Int.max }

        // Find the decimal point in the input
        guard let decimalIndex = input.firstIndex(of: ".") else {
            // No decimal typed - all formatted fractional digits are placeholders
            return 0
        }

        // Count digits after the decimal
        let afterDecimal = input[input.index(after: decimalIndex)...]
        return afterDecimal.filter { $0.isNumber }.count
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
