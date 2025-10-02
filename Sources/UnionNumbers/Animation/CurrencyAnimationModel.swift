//
//  CurrencyAnimationModel.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.
//

import CoreText
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UnionGradients
import UnionShake

@available(macOS 14.0, *)
@MainActor
@Observable class CurrencyAnimationModel {
    enum ValueErrorLimit {
        case unknown
        case belowMinimum
        case aboveMaximum
    }

    var digits: [AnimatedDigit] = []
    var oldDigits: [Int: AnimatedDigit] = [:]
    var isTransitioningFromZero: Bool = false
    var isTransitioningToZero: Bool = false
    var isAnimating: Bool = false
    var isAddingDecimal: Bool = false
    var isDeletingDecimal: Bool = false

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    private let queue = AnimationQueue()
    private var currentValue: String = "0"
    private var previousDigits: [AnimatedDigit] = []
    private var isInitialLoad = true

    private struct NumberParts {
        let raw: String
        let sanitized: String
        let integer: String
        let decimal: String?
        let hasDecimal: Bool
        let hasTrailingDecimalSeparator: Bool
        let digitsOnly: String
        let doubleValue: Double

        init(_ value: String) {
            raw = value
            sanitized = value.replacingOccurrences(of: ",", with: "")
            hasDecimal = sanitized.contains(".")
            hasTrailingDecimalSeparator = hasDecimal && sanitized.hasSuffix(".")

            let segments = sanitized.split(
                separator: ".",
                omittingEmptySubsequences: false
            )

            if segments.isEmpty {
                integer = ""
                decimal = hasDecimal ? "" : nil
            } else {
                integer = String(segments[0])
                if segments.count >= 2 {
                    decimal = String(segments[1])
                } else if hasDecimal {
                    decimal = ""
                } else {
                    decimal = nil
                }
            }

            digitsOnly = sanitized.replacingOccurrences(of: ".", with: "")
            doubleValue = Double(sanitized) ?? 0
        }

        var normalizedForValidation: String {
            digitsOnly.isEmpty ? "0" : sanitized
        }

        var decimalCount: Int {
            decimal?.count ?? 0
        }

        var significantDecimalCount: Int {
            guard let decimal else { return 0 }
            return countDecimals(decimal)
        }

        private func countDecimals(_ decimal: String) -> Int {
            var count: Int = 0
            for (index, character) in decimal.enumerated() {
                if (character != "0" || index < decimal.count - 1 || decimal.count == 1) {
                    count = index + 1
                }
            }
            return count
        }
    }

    func setValue(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) {
        Task { @MainActor in
            if self.isInitialLoad {
                let trimmed = newValue.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let initialValue = trimmed.isEmpty ? "0" : trimmed
                let isValueValid = await self.applyValue(
                    initialValue,
                    minValue: minValue,
                    maxValue: maxValue
                )
                return
            }
            await queue.enqueue(newValue) { @MainActor [weak self] value in
                guard let self = self else { return }
                let isValueValid = await self.applyValue(
                    value,
                    minValue: minValue,
                    maxValue: maxValue
                )
            }
        }
    }

    public func isValueInBounds(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) -> (Bool, ValueErrorLimit?) {
        let parts = NumberParts(newValue)

        if let decimalPart = parts.decimal,
            decimalPart.count > formatter.maximumFractionDigits
        {
            return (false, ValueErrorLimit.unknown)
        }

        guard let decimalValue = formatter
            .number(from: parts.normalizedForValidation)?.decimalValue
        else {
            return (false, ValueErrorLimit.unknown)
        }

        if decimalValue < minValue {
            return (false, ValueErrorLimit.belowMinimum)
        } else if decimalValue > maxValue {
            return (false, ValueErrorLimit.aboveMaximum)
        }
        return (true, nil)
    }

    private func getDisplayValueAndHasPlaceholderZeros(
        from newValue: String
    ) -> (displayValue: String, hasPlaceholderZeros: Bool) {
        let parts = NumberParts(newValue)

        guard parts.hasDecimal else {
            return (newValue, false)
        }

        if let decimalPart = parts.decimal,
            decimalPart.count > formatter.maximumFractionDigits
        {
            return (newValue, false)
        }

        if let decimalPart = parts.decimal,
            decimalPart.count < formatter.maximumFractionDigits
        {
            let zerosNeeded =
                formatter.maximumFractionDigits - decimalPart.count
            let paddedDecimal =
                decimalPart + String(repeating: "0", count: zerosNeeded)
            return ("\(parts.integer).\(paddedDecimal)", true)
        }

        if parts.hasTrailingDecimalSeparator {
            let zeros = String(
                repeating: "0",
                count: formatter.maximumFractionDigits
            )
            return ("\(parts.integer).\(zeros)", true)
        }

        return (newValue, false)
    }

    private func applyValue(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) async -> Bool {
        let rawParts = NumberParts(newValue)
        let (displayValue, hasPlaceholderZeros) =
            self.getDisplayValueAndHasPlaceholderZeros(from: newValue)
        let displayParts = NumberParts(displayValue)

        let valueToValidate = rawParts.normalizedForValidation
        let decimal = formatter.number(from: valueToValidate)!.decimalValue

        let oldValue = currentValue
        currentValue = displayValue

        let oldParts = NumberParts(oldValue)

        let oldNum = oldParts.doubleValue
        let newNum = rawParts.doubleValue

        isTransitioningFromZero = oldNum == 0 && newNum > 0
        isTransitioningToZero = oldNum > 0 && newNum == 0

        isAddingDecimal = !oldParts.hasDecimal && rawParts.hasDecimal
        isDeletingDecimal = oldParts.hasDecimal && !rawParts.hasDecimal

        var formatted: String
        if hasPlaceholderZeros {
            if let formattedInteger = formatter.string(
                from: NSDecimalNumber(string: displayParts.integer)
            ) {
                let decimalPart = displayParts.decimal ?? ""
                formatted =
                    formattedInteger
                    + (decimalPart.isEmpty ? "" : "." + decimalPart)
            } else {
                formatted = displayValue
            }
        } else if rawParts.hasDecimal,
            let decimalPart = rawParts.decimal
        {
            if let formattedInteger = formatter.string(
                from: NSDecimalNumber(string: rawParts.integer)
            ) {
                formatted = formattedInteger + "." + decimalPart
            } else {
                formatted = displayValue
            }
        } else {
            formatted =
                formatter.string(from: NSDecimalNumber(decimal: decimal))
                ?? displayValue
        }

        let isRemovingDigit = rawParts.sanitized.count < oldParts.sanitized.count

        let newDigits = createDigitsWithStableIdentity(
            from: formatted,
            previousDigits: previousDigits,
            oldValue: oldValue,
            newValue: displayValue,
            rawValue: newValue,
            isDeletingDecimal: isDeletingDecimal
        )

        if isInitialLoad {
            self.oldDigits = self.digits.reduce(into: [:], { partialResult, animatedDigit in
                partialResult[animatedDigit.digitIndex] = animatedDigit
            })
            digits = newDigits
            isInitialLoad = false
        } else {
            isAnimating = true
            let animation =
                isRemovingDigit
                ? AnimatedNumberConfig.AnimationTiming.spring.removal
                : AnimatedNumberConfig.AnimationTiming.spring.standard
            withAnimation(animation) {
                self.oldDigits = self.digits.reduce(into: [:], { partialResult, animatedDigit in
                    partialResult[animatedDigit.digitIndex] = animatedDigit
                })
                digits = newDigits
            }
        }

        previousDigits = newDigits

        if !isInitialLoad {
            Task {
                try? await Task.sleep(
                    for: .seconds(
                        AnimatedNumberConfig.AnimationTiming
                            .transitionReset
                    )
                )
                isTransitioningFromZero = false
                isTransitioningToZero = false
                isAnimating = false
                isAddingDecimal = false
                isDeletingDecimal = false
            }
        }

        return true
    }

    private func onlyDecimalIsChanging(
        oldParts: NumberParts,
        newParts: NumberParts
    ) -> Bool {
        guard oldParts.integer == newParts.integer else {
            return false
        }
        return oldParts.hasDecimal || newParts.hasDecimal
    }

    private func isAddingDecimals(
        oldParts: NumberParts,
        newParts: NumberParts
    ) -> Bool {
        !oldParts.hasDecimal && newParts.hasDecimal
            && oldParts.integer == newParts.integer
    }

    private func isChangingDigits(
        oldDigitsOnly: String,
        newDigitsOnly: String,
        isOnlyDecimalChanging: Bool
    ) -> Bool {
        if oldDigitsOnly.isEmpty || newDigitsOnly.isEmpty
            || oldDigitsOnly == "0" || isOnlyDecimalChanging
        {
            return false
        }

        if oldDigitsOnly.count != newDigitsOnly.count {
            return true
        }

        return zip(oldDigitsOnly, newDigitsOnly).contains { $0 != $1 }
    }

    private func createDigitsWithStableIdentity(
        from formatted: String,
        previousDigits: [AnimatedDigit],
        oldValue: String,
        newValue: String,
        rawValue: String? = nil,
        isDeletingDecimal: Bool = false
    ) -> [AnimatedDigit] {
        let formattedChars = Array(formatted)
        var result: [AnimatedDigit] = []

        var decimalIndex = -1
        var isAfterDecimal = false

        let oldParts = NumberParts(oldValue)
        let newParts = NumberParts(newValue)
        let rawParts = NumberParts(rawValue ?? newValue)

        let oldDigitsOnly = oldParts.digitsOnly
        let newDigitsOnly = newParts.digitsOnly

        let oldNum = oldParts.doubleValue
        let newNum = newParts.doubleValue

        let isTransitionFromZero = oldNum == 0 && newNum > 0
        let isTransitionToZero = oldNum > 0 && newNum == 0

        let isJustAddingDecimal = self.isAddingDecimals(
            oldParts: oldParts,
            newParts: newParts
        )

        let isSingleDigitFromZero =
            oldDigitsOnly == "0" && newDigitsOnly.count == 1 && newNum > 0
        let isSingleDigitToZero =
            newDigitsOnly == "0" && oldDigitsOnly.count == 1 && oldNum > 0

        let isOnlyDecimalChanging = self.onlyDecimalIsChanging(
            oldParts: oldParts,
            newParts: newParts
        )

        let hasChangingDigits = self.isChangingDigits(
            oldDigitsOnly: oldDigitsOnly,
            newDigitsOnly: newDigitsOnly,
            isOnlyDecimalChanging: isOnlyDecimalChanging
        )

        var previousDigitsByPositionAndChar: [String: String] = [:]
        if !hasChangingDigits {
            for digit in previousDigits
            where digit.char != "," && digit.char != "." && !digit.isPlaceholder
            {
                let key = "\(digit.digitIndex)-\(digit.char)"
                previousDigitsByPositionAndChar[key] = digit.id
            }
        }

        var digitPosition = 0
        var charIndex = 0

        for char in formattedChars {
            var isNew = false
            var isZeroTransition = false

            if char == "," {
                result.append(
                    AnimatedDigit(
                        char: char,
                        digitIndex: digitPosition,
                        isNew: false,
                        isZeroTransition: false,
                        isPlaceholder: false,
                        isReplacingDigit: false,
                        isPlaceholderToRealTransition: false
                    )
                )
            } else if char == "." {
                isAfterDecimal = true
                decimalIndex = charIndex
                result.append(
                    AnimatedDigit(
                        char: char,
                        digitIndex: digitPosition,
                        isNew: isJustAddingDecimal,
                        isZeroTransition: false,
                        isPlaceholder: false,
                        isReplacingDigit: false,
                        isPlaceholderToRealTransition: false
                    )
                )
            } else {
                let isIntegerDigitWithDecimalChange =
                    !isAfterDecimal && isOnlyDecimalChanging

                var isReplacingDigit = false
                var isPlaceholder = false
                let isPlaceholderToReal = false

                if char == "0" && digitPosition == 0 && !isAfterDecimal {
                    if newNum < 1 {
                        isPlaceholder = true
                    }
                } else if isAfterDecimal && char == "0" {
                    let decimalPosition = charIndex - decimalIndex - 1
                    let rawDecimalCount = rawParts.decimalCount
                    isPlaceholder = decimalPosition >= rawDecimalCount

                    if isPlaceholder && oldParts.hasDecimal {
                        if decimalPosition < oldParts.significantDecimalCount {
                            isReplacingDigit = true
                        }
                    }
                }

                let isReplacingDecimalPlaceholder =
                    isAfterDecimal && !isPlaceholder
                    && {
                        let prevDigitAtPos = previousDigits.first {
                            $0.digitIndex == digitPosition
                        }
                        return prevDigitAtPos?.isPlaceholder == true
                    }()

                if !isInitialLoad && !isPlaceholder && !isJustAddingDecimal
                    && !isIntegerDigitWithDecimalChange
                {
                    if isSingleDigitToZero && char == "0" {
                        isNew = true
                        isZeroTransition = true
                    } else if isSingleDigitFromZero && char != "0" {
                        isNew = true
                        isZeroTransition = false
                    } else if isTransitionToZero && char == "0"
                        && digitPosition == 0
                    {
                        isNew = true
                        isZeroTransition = true
                    } else if isTransitionFromZero
                        && digitPosition == newDigitsOnly.count - 1
                    {
                        isNew = true
                        isZeroTransition = false
                    }

                    if isReplacingDecimalPlaceholder {
                        isNew = true
                    }
                }

                let lookupKey = "\(digitPosition)-\(char)"
                let hasMatchingDigit =
                    !isPlaceholder
                    && previousDigitsByPositionAndChar[lookupKey] != nil

                if !isNew && !isPlaceholder && !hasMatchingDigit
                    && !isInitialLoad
                {
                    if isOnlyDecimalChanging && !isAfterDecimal {
                        isNew = false
                    } else {
                        isNew = true
                    }
                }

                var finalIsNew = isNew

                if isIntegerDigitWithDecimalChange {
                    finalIsNew = false
                }

                result.append(
                    AnimatedDigit(
                        char: char,
                        digitIndex: digitPosition,
                        isNew: finalIsNew
                            || (isPlaceholder && isJustAddingDecimal
                                && digitPosition != 0),
                        isZeroTransition: isZeroTransition,
                        isPlaceholder: isPlaceholder,
                        isReplacingDigit: isReplacingDigit
                            || (isPlaceholder && !isJustAddingDecimal),
                        isPlaceholderToRealTransition: isPlaceholderToReal
                    )
                )
                digitPosition += 1
            }
            charIndex += 1
        }

        return result
    }

}
