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
            
            integer = String(segments.first ?? "")
            if segments.count >= 2 {
                decimal = String(segments[1])
            } else if hasDecimal {
                decimal = ""
            } else {
                decimal = nil
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
    
    private struct AnimationData {
        let isJustAddingDecimal: Bool
        let isOnlyDecimalChanging: Bool
        let hasChangingDigits: Bool
        let isTransitionFromZero: Bool
        let isTransitionToZero: Bool
        let isSingleDigitFromZero: Bool
        let isSingleDigitToZero: Bool
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
    
    private func getDisplayValue(from newValue: String) -> String {
        let parts = NumberParts(newValue)
        
        guard parts.hasDecimal else {
            return newValue
        }
        
        if let decimalPart = parts.decimal,
           decimalPart.count > formatter.maximumFractionDigits {
            return newValue
        }
        
        if let decimalPart = parts.decimal,
           decimalPart.count < formatter.maximumFractionDigits {
            let zerosNeeded = formatter.maximumFractionDigits - decimalPart.count
            let paddedDecimal = decimalPart + String(repeating: "0", count: zerosNeeded)
            return "\(parts.integer).\(paddedDecimal)"
        }
        
        if parts.hasTrailingDecimalSeparator {
            let zeros = String(repeating: "0", count: formatter.maximumFractionDigits)
            return "\(parts.integer).\(zeros)"
        }
        
        return newValue
    }
    
    private func checkPlaceholderZeros(in newValue: String) -> Bool {
        let parts = NumberParts(newValue)
        
        guard parts.hasDecimal else {
            return false
        }
        
        if let decimalPart = parts.decimal,
           decimalPart.count < formatter.maximumFractionDigits {
            return true
        }
        
        if parts.hasTrailingDecimalSeparator {
            return true
        }
        
        return false
    }
    
    private func prepareValues(_ newValue: String) -> (
        rawParts: NumberParts,
        displayValue: String,
        hasPlaceholderZeros: Bool,
        displayParts: NumberParts,
        decimal: Decimal,
        oldValue: String,
        oldParts: NumberParts
    ) {
        let rawParts = NumberParts(newValue)
        let displayValue = getDisplayValue(from: newValue)
        let hasPlaceholderZeros = checkPlaceholderZeros(in: newValue)
        let displayParts = NumberParts(displayValue)
        
        let valueToValidate = rawParts.normalizedForValidation
        let decimal = formatter.number(from: valueToValidate)!.decimalValue
        
        let oldValue = currentValue
        currentValue = displayValue
        let oldParts = NumberParts(oldValue)
        
        return (rawParts, displayValue, hasPlaceholderZeros, displayParts, decimal, oldValue, oldParts)
    }
    
    private func formatString(
        rawParts: NumberParts,
        displayParts: NumberParts,
        displayValue: String,
        hasPlaceholderZeros: Bool,
        decimal: Decimal
    ) -> String {
        var formatted: String
        
        if hasPlaceholderZeros {
            if let formattedInteger = formatter.string(
                from: NSDecimalNumber(string: displayParts.integer)
            ) {
                let decimalPart = displayParts.decimal ?? ""
                formatted = formattedInteger + (decimalPart.isEmpty ? "" : "." + decimalPart)
            } else {
                formatted = displayValue
            }
        } else if rawParts.hasDecimal, let decimalPart = rawParts.decimal {
            if let formattedInteger = formatter.string(
                from: NSDecimalNumber(string: rawParts.integer)
            ) {
                formatted = formattedInteger + "." + decimalPart
            } else {
                formatted = displayValue
            }
        } else {
            formatted = formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? displayValue
        }
        
        return formatted
    }
    
    private func renderDigits(newDigits: [AnimatedDigit], isRemovingDigit: Bool) {
        if isInitialLoad {
            self.oldDigits = self.digits.reduce(into: [:], { partialResult, animatedDigit in
                partialResult[animatedDigit.digitIndex] = animatedDigit
            })
            digits = newDigits
            isInitialLoad = false
        } else {
            isAnimating = true
            let animation = isRemovingDigit
            ? AnimatedNumberConfig.AnimationTiming.spring.removal
            : AnimatedNumberConfig.AnimationTiming.spring.standard
            withAnimation(animation) {
                self.oldDigits = self.digits.reduce(into: [:], { partialResult, animatedDigit in
                    partialResult[animatedDigit.digitIndex] = animatedDigit
                })
                digits = newDigits
            }
        }
    }
    
    private func updateTransitionFlags(
        oldNum: Double,
        newNum: Double,
        oldParts: NumberParts,
        rawParts: NumberParts
    ) {
        isTransitioningFromZero = oldNum == 0 && newNum > 0
        isTransitioningToZero = oldNum > 0 && newNum == 0
        isAddingDecimal = !oldParts.hasDecimal && rawParts.hasDecimal
        isDeletingDecimal = oldParts.hasDecimal && !rawParts.hasDecimal
    }
    
    private func scheduleResetFlags() {
        Task {
            try? await Task.sleep(
                for: .seconds(
                    AnimatedNumberConfig.AnimationTiming.transitionReset
                )
            )
            isTransitioningFromZero = false
            isTransitioningToZero = false
            isAnimating = false
            isAddingDecimal = false
            isDeletingDecimal = false
        }
    }
    
    private func applyValue(
        _ newValue: String,
        minValue: Decimal,
        maxValue: Decimal
    ) async -> Bool {
        let (rawParts, displayValue, hasPlaceholderZeros, displayParts, decimal, oldValue, oldParts) = prepareValues(newValue)
        
        let oldNum = oldParts.doubleValue
        let newNum = rawParts.doubleValue
        updateTransitionFlags(oldNum: oldNum, newNum: newNum, oldParts: oldParts, rawParts: rawParts)
        
        let formatted = formatString(
            rawParts: rawParts,
            displayParts: displayParts,
            displayValue: displayValue,
            hasPlaceholderZeros: hasPlaceholderZeros,
            decimal: decimal
        )
        
        let isRemovingDigit = rawParts.sanitized.count < oldParts.sanitized.count
        let newDigits = createDigits(
            from: formatted,
            previousDigits: previousDigits,
            oldValue: oldValue,
            newValue: displayValue,
            rawValue: newValue,
            isDeletingDecimal: isDeletingDecimal
        )
        
        renderDigits(newDigits: newDigits, isRemovingDigit: isRemovingDigit)
        previousDigits = newDigits
        
        if !isInitialLoad {
            scheduleResetFlags()
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
        guard !oldDigitsOnly.isEmpty, !newDigitsOnly.isEmpty, oldDigitsOnly != "0", !isOnlyDecimalChanging
        else {
            return false
        }
        
        if oldDigitsOnly.count != newDigitsOnly.count {
            return true
        }
        
        return zip(oldDigitsOnly, newDigitsOnly).contains { $0 != $1 }
    }
    
    private func prepareAnimationData(
        oldParts: NumberParts,
        newParts: NumberParts
    ) -> AnimationData {
        let isJustAddingDecimal = self.isAddingDecimals(
            oldParts: oldParts,
            newParts: newParts
        )
        
        let isOnlyDecimalChanging = self.onlyDecimalIsChanging(
            oldParts: oldParts,
            newParts: newParts
        )
        
        let hasChangingDigits = self.isChangingDigits(
            oldDigitsOnly: oldParts.digitsOnly,
            newDigitsOnly: newParts.digitsOnly,
            isOnlyDecimalChanging: isOnlyDecimalChanging
        )
        
        let isTransitionFromZero = oldParts.doubleValue == 0 && newParts.doubleValue > 0
        let isTransitionToZero = oldParts.doubleValue > 0 && newParts.doubleValue == 0
        
        let isSingleDigitFromZero =
        oldParts.digitsOnly == "0" && newParts.digitsOnly.count == 1 && newParts.doubleValue > 0
        let isSingleDigitToZero =
        newParts.digitsOnly == "0" && oldParts.digitsOnly.count == 1 && oldParts.doubleValue > 0
        
        return AnimationData(
            isJustAddingDecimal: isJustAddingDecimal,
            isOnlyDecimalChanging: isOnlyDecimalChanging,
            hasChangingDigits: hasChangingDigits,
            isTransitionFromZero: isTransitionFromZero,
            isTransitionToZero: isTransitionToZero,
            isSingleDigitFromZero: isSingleDigitFromZero,
            isSingleDigitToZero: isSingleDigitToZero
        )
    }
    
    private func buildAnimatedDigits(
        formatted: String,
        previousDigits: [AnimatedDigit],
        context: AnimationData,
        oldParts: NumberParts,
        newParts: NumberParts,
        rawParts: NumberParts
    ) -> [AnimatedDigit] {
        let formattedChars = Array(formatted)
        var result: [AnimatedDigit] = []
        
        var decimalIndex = -1
        var isAfterDecimal = false
        
        var previousDigitsMap: [String: String] = [:]
        if !context.hasChangingDigits {
            for digit in previousDigits
            where digit.char != "," && digit.char != "." && !digit.isPlaceholder
            {
                let key = "\(digit.digitIndex)-\(digit.char)"
                previousDigitsMap[key] = digit.id
            }
        }
        
        var digitPosition = 0

        for (charIndex, char) in formattedChars.enumerated() {
            switch char {
            case ",":
                result.append(
                    AnimatedDigit(
                        char: char,
                        digitIndex: digitPosition
                    )
                )
            case ".":
                isAfterDecimal = true
                decimalIndex = charIndex
                result.append(
                    AnimatedDigit(
                        char: char,
                        digitIndex: digitPosition,
                        isNew: context.isJustAddingDecimal
                    )
                )
            default:
                result.append(
                    buildDigit(
                        character: char,
                        digitPosition: digitPosition,
                        charIndex: charIndex,
                        decimalIndex: decimalIndex,
                        isAfterDecimal: isAfterDecimal,
                        previousDigits: previousDigits,
                        previousDigitsMap: previousDigitsMap,
                        context: context,
                        oldParts: oldParts,
                        newParts: newParts,
                        rawParts: rawParts
                    )
                )
                digitPosition += 1
            }
        }

        return result
    }

    private func buildDigit(
        character char: Character,
        digitPosition: Int,
        charIndex: Int,
        decimalIndex: Int,
        isAfterDecimal: Bool,
        previousDigits: [AnimatedDigit],
        previousDigitsMap: [String: String],
        context: AnimationData,
        oldParts: NumberParts,
        newParts: NumberParts,
        rawParts: NumberParts
    ) -> AnimatedDigit {
        let isIntegerDigitWithDecimalChange = !isAfterDecimal && context.isOnlyDecimalChanging

        var isReplacingDigit = false
        var isPlaceholder = false

        if char == "0" && digitPosition == 0 && !isAfterDecimal {
            if newParts.doubleValue < 1 {
                isPlaceholder = true
            }
        } else if isAfterDecimal && char == "0" {
            let decimalPosition = charIndex - decimalIndex - 1
            let rawDecimalCount = rawParts.decimalCount
            if rawParts.hasTrailingDecimalSeparator {
                isPlaceholder = decimalPosition >= rawDecimalCount
            }

            if isPlaceholder && oldParts.hasDecimal {
                if decimalPosition < oldParts.significantDecimalCount {
                    isReplacingDigit = true
                }
            }
        }

        let isReplacingDecimalPlaceholder = isAfterDecimal && !isPlaceholder && {
            let prevDigitAtPos = previousDigits.first { $0.digitIndex == digitPosition }
            return prevDigitAtPos?.isPlaceholder == true
        }()

        let lookupKey = "\(digitPosition)-\(char)"
        let hasMatchingDigit = !isPlaceholder && previousDigitsMap[lookupKey] != nil

        let isTransitioningToZero = (context.isSingleDigitToZero && char == "0") || (context.isTransitionToZero && char == "0" && digitPosition == 0)
        let isTransitioningFromZero = (context.isSingleDigitFromZero && char != "0") || (context.isTransitionFromZero && digitPosition == newParts.digitsOnly.count - 1)
        let isZeroTransitionEvent = isTransitioningToZero || isTransitioningFromZero

        let canBeConsideredNew = !isInitialLoad && !isPlaceholder
        let isNewFromEvent = !context.isJustAddingDecimal && !isIntegerDigitWithDecimalChange && (isZeroTransitionEvent || isReplacingDecimalPlaceholder)

        let isNewFromMismatch = !hasMatchingDigit && !(context.isOnlyDecimalChanging && !isAfterDecimal)
        let isNewCandidate = canBeConsideredNew && (isNewFromEvent || isNewFromMismatch)
        let finalIsNew = (isNewCandidate && !isIntegerDigitWithDecimalChange) || (isPlaceholder && context.isJustAddingDecimal && digitPosition != 0)

        return AnimatedDigit(
            char: char,
            digitIndex: digitPosition,
            isNew: finalIsNew,
            isZeroTransition: isTransitioningToZero,
            isPlaceholder: isPlaceholder,
            isReplacingDigit: isReplacingDigit || (isPlaceholder && !context.isJustAddingDecimal)
        )
    }
    
    private func createDigits(
        from formatted: String,
        previousDigits: [AnimatedDigit],
        oldValue: String,
        newValue: String,
        rawValue: String? = nil,
        isDeletingDecimal: Bool = false
    ) -> [AnimatedDigit] {
        let oldParts = NumberParts(oldValue)
        let newParts = NumberParts(newValue)
        let rawParts = NumberParts(rawValue ?? newValue)
        
        let data = prepareAnimationData(
            oldParts: oldParts,
            newParts: newParts
        )
        
        return buildAnimatedDigits(
            formatted: formatted,
            previousDigits: previousDigits,
            context: data,
            oldParts: oldParts,
            newParts: newParts,
            rawParts: rawParts
        )
    }
}
