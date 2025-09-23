//
//  CurrencyAnimationModel.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.
//

import CoreText
import Foundation
import SwiftUI
import UIKit
import UnionGradients
import UnionShake

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
                let isValid = await self.applyValue(
                    initialValue,
                    minValue: minValue,
                    maxValue: maxValue
                )
                return
            }
            await queue.enqueue(newValue) { @MainActor [weak self] value in
                let isValid =
                    await self?.applyValue(
                        value,
                        minValue: minValue,
                        maxValue: maxValue
                    ) ?? false
            }
        }
    }

    public func isValueValid(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) -> (Bool, ValueErrorLimit?) {
        if newValue.contains(".") {
            let parts = newValue.split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            if parts.count == 2 {
                let integerPart = String(parts[0])
                let decimalPart = String(parts[1])

                if decimalPart.count > formatter.maximumFractionDigits {
                    return (false, ValueErrorLimit.unknown)
                }
            }

        }
        let valueToValidate =
            newValue.replacingOccurrences(of: ".", with: "").isEmpty
            ? "0" : newValue

        let decimal = formatter.number(from: valueToValidate)?.decimalValue

        if decimal == nil {
            return (false, ValueErrorLimit.unknown)
        }
        if decimal! < minValue {
            return (false, ValueErrorLimit.belowMinimum)
        }
        if decimal! > maxValue {
            return (false, ValueErrorLimit.aboveMaximum)
        }
        return (true, nil)
    }

    private func getDisplayValueAndHasPlaceholderZeros(
        from newValue: String
    ) -> (displayValue: String, hasPlaceholderZeros: Bool) {
        var displayValue = newValue
        var hasPlaceholderZeros = false

        if newValue.contains(".") {
            let parts = newValue.split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            if parts.count == 2 {
                let integerPart = String(parts[0])
                let decimalPart = String(parts[1])

                if decimalPart.count > formatter.maximumFractionDigits {
                    return (displayValue, hasPlaceholderZeros)
                }

                if decimalPart.count < formatter.maximumFractionDigits {
                    hasPlaceholderZeros = true
                    let zerosNeeded =
                        formatter.maximumFractionDigits - decimalPart.count
                    displayValue =
                        integerPart + "." + decimalPart
                        + String(repeating: "0", count: zerosNeeded)
                }
            } else if parts.count == 1 && newValue.hasSuffix(".") {
                hasPlaceholderZeros = true
                displayValue =
                    newValue
                    + String(
                        repeating: "0",
                        count: formatter.maximumFractionDigits
                    )
            }
        }

        return (displayValue, hasPlaceholderZeros)
    }

    private func applyValue(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) async -> Bool {
        let (displayValue, hasPlaceholderZeros) =
            self.getDisplayValueAndHasPlaceholderZeros(from: newValue)

        let valueToValidate =
            newValue.replacingOccurrences(of: ".", with: "").isEmpty
            ? "0" : newValue

        let decimal = formatter.number(from: valueToValidate)!.decimalValue

        let oldValue = currentValue
        currentValue = displayValue

        let oldClean = oldValue.replacingOccurrences(of: ",", with: "")
        let newClean = newValue.replacingOccurrences(of: ",", with: "")
        let oldNum = Double(oldClean) ?? 0
        let newNum = Double(newClean) ?? 0

        isTransitioningFromZero = oldNum == 0 && newNum > 0
        isTransitioningToZero = oldNum > 0 && newNum == 0

        isAddingDecimal = !oldValue.contains(".") && newValue.contains(".")
        isDeletingDecimal = oldValue.contains(".") && !newValue.contains(".")

        var formatted: String
        if hasPlaceholderZeros {
            let parts = displayValue.split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            if parts.count >= 1 {
                let integerPart = String(parts[0])
                let decimalPart = parts.count > 1 ? String(parts[1]) : ""

                if let formattedInteger = formatter.string(
                    from: NSDecimalNumber(string: integerPart)
                ) {
                    formatted =
                        formattedInteger
                        + (decimalPart.isEmpty ? "" : "." + decimalPart)
                } else {
                    formatted = displayValue
                }
            } else {
                formatted = displayValue
            }
        } else {
            if newValue.contains(".") {
                let parts = newValue.split(
                    separator: ".",
                    omittingEmptySubsequences: false
                )
                if parts.count == 2 {
                    let integerPart = String(parts[0])
                    let decimalPart = String(parts[1])

                    if let formattedInteger = formatter.string(
                        from: NSDecimalNumber(string: integerPart)
                    ) {
                        formatted = formattedInteger + "." + decimalPart
                    } else {
                        formatted = displayValue
                    }
                } else {
                    formatted =
                        formatter.string(
                            from: NSDecimalNumber(decimal: decimal)
                        ) ?? displayValue
                }
            } else {
                formatted =
                    formatter.string(from: NSDecimalNumber(decimal: decimal))
                    ?? displayValue
            }
        }

        let isRemovingDigit = newClean.count < oldClean.count

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
                    nanoseconds: AnimatedNumberConfig.AnimationTiming
                        .transitionReset.nanos
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

    private func removePunctuation(from value: String, removeDot: Bool = true)
        -> String
    {
        let replacedComma = value.replacingOccurrences(of: ",", with: "")
        if !removeDot {
            return replacedComma
        }
        return replacedComma.replacingOccurrences(of: ".", with: "")
    }

    private func getIntegerPart(from value: String) -> String {
        value.contains(".")
            ? String(value.split(separator: ".")[0]) : value
    }

    private func onlyDecimalIsChanging(oldValue: String, newValue: String)
        -> Bool
    {
        if !oldValue.contains(".") && newValue.contains(".") {
            let oldClean = self.removePunctuation(
                from: oldValue,
                removeDot: false
            )
            let newIntPart = newValue.split(separator: ".").first ?? ""
            let newIntPartClean = self.removePunctuation(
                from: String(newIntPart),
                removeDot: false
            )
            return oldClean == newIntPartClean
        }
        if oldValue.contains(".") && !newValue.contains(".") {
            let newClean = self.removePunctuation(
                from: newValue,
                removeDot: false
            )
            let oldIntPart = oldValue.split(separator: ".").first ?? ""
            let oldIntPartClean = self.removePunctuation(
                from: String(oldIntPart),
                removeDot: false
            )
            return newClean == oldIntPartClean
        }
        if oldValue.contains(".") && newValue.contains(".") {
            let oldIntPart = oldValue.split(separator: ".").first ?? ""
            let newIntPart = newValue.split(separator: ".").first ?? ""
            return oldIntPart == newIntPart
        }
        return false
    }

    private func isAddingDecimals(oldValue: String, newValue: String) -> Bool {
        let oldIntegerPart = self.getIntegerPart(from: oldValue)
        let newIntegerPart = self.getIntegerPart(from: newValue)

        return !oldValue.contains(".") && newValue.contains(".")
            && oldIntegerPart == newIntegerPart
    }

    private func isChangingDigits(
        oldDigitsOnly: String,
        newDigitsOnly: String,
        isOnlyDecimalChanging: Bool
    ) -> Bool {
        if oldDigitsOnly.isEmpty || newDigitsOnly.isEmpty
            || oldDigitsOnly == "0"
        {
            return false
        }

        if isOnlyDecimalChanging {
            return false
        }

        let minLen = min(oldDigitsOnly.count, newDigitsOnly.count)
        for i in 0..<minLen {
            let oldIndex = oldDigitsOnly.index(
                oldDigitsOnly.startIndex,
                offsetBy: i
            )
            let newIndex = newDigitsOnly.index(
                newDigitsOnly.startIndex,
                offsetBy: i
            )
            if oldDigitsOnly[oldIndex] != newDigitsOnly[newIndex] {
                return true
            }
        }
        return false
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

        let oldDigitsOnly = self.removePunctuation(from: oldValue)
        let newDigitsOnly = self.removePunctuation(from: newValue)

        let oldNum =
            Double(self.removePunctuation(from: oldValue, removeDot: false))
            ?? 0
        let newNum =
            Double(self.removePunctuation(from: newValue, removeDot: false))
            ?? 0

        let isTransitionFromZero = oldNum == 0 && newNum > 0
        let isTransitionToZero = oldNum > 0 && newNum == 0

        let isJustAddingDecimal = self.isAddingDecimals(
            oldValue: oldValue,
            newValue: newValue
        )

        let isSingleDigitFromZero =
            oldDigitsOnly == "0" && newDigitsOnly.count == 1 && newNum > 0
        let isSingleDigitToZero =
            newDigitsOnly == "0" && oldDigitsOnly.count == 1 && oldNum > 0

        let isOnlyDecimalChanging: Bool = self.onlyDecimalIsChanging(
            oldValue: oldValue,
            newValue: newValue
        )

        let hasChangingDigits: Bool = self.isChangingDigits(
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

                    let actualRawValue = rawValue ?? newValue
                    if actualRawValue.contains(".") {
                        let rawParts = actualRawValue.split(
                            separator: ".",
                            omittingEmptySubsequences: false
                        )
                        if rawParts.count == 2 {
                            let rawDecimalPart = String(rawParts[1])
                            isPlaceholder =
                                decimalPosition >= rawDecimalPart.count

                            if isPlaceholder && oldValue.contains(".") {
                                let oldParts = oldValue.split(
                                    separator: ".",
                                    omittingEmptySubsequences: false
                                )
                                if oldParts.count == 2 {
                                    let oldDecimalPart = String(oldParts[1])
                                    var oldRawDecimalCount = 0
                                    for (i, ch) in oldDecimalPart.enumerated() {
                                        if ch != "0"
                                            || i < oldDecimalPart.count - 1
                                            || oldDecimalPart.count == 1
                                        {
                                            oldRawDecimalCount = i + 1
                                        }
                                    }
                                    if decimalPosition < oldRawDecimalCount {
                                        isReplacingDigit = true
                                    }
                                }
                            }
                        } else if rawParts.count == 1
                            && actualRawValue.hasSuffix(".")
                        {
                            isPlaceholder = true
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
