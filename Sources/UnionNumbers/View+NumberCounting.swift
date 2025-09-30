//
//  View+NumberCounting.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import Foundation
import SwiftUI
import UnionGradients

#if canImport(UIKit)
import UIKit
#endif

private struct NumberCountingView: View {
    let prefix: String?
    let digits: [AnimatedDigit]
    let oldDigits: [Int: AnimatedDigit]
    let font: Font
    let fontSize: CGFloat
    let foregroundColor: Color
    let currentOpacity: Double
    let digitScale: CGFloat
    let shouldShake: Bool
    let isTransitioningFromZero: Bool
    let isTransitioningToZero: Bool
    let isAddingDecimal: Bool
    let isDeletingDecimal: Bool
    let digitIDs: [AnimatedDigit.ID]
    let onContentWidthChange: (CGFloat) -> Void
    
    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 4) {
                HStack(spacing: 0) {
                    if let prefix {
                        Text(prefix)
                            .font(font)
                            .foregroundColor(foregroundColor)
                            .opacity(currentOpacity)
                    }
                    
                    ForEach(digits, id: \.id) { digit in
                        SimplifiedDigitView(
                            digit: digit,
                            oldDigit: oldDigits[digit.digitIndex],
                            fontSize: fontSize,
                            font: font,
                            color: foregroundColor,
                            isTransitioningFromZero: isTransitioningFromZero,
                            isTransitioningToZero: isTransitioningToZero,
                            isAddingDecimal: isAddingDecimal,
                            isDeletingDecimal: isDeletingDecimal,
                            overallOpacity: currentOpacity
                        )
                        .fixedSize()
                        .zIndex(zIndex(for: digit))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                onContentWidthChange(geometry.size.width)
                            }
                            .onChange(of: geometry.size.width) { _, newWidth in
                                onContentWidthChange(newWidth)
                            }
                            .onChange(of: digitIDs) { _, _ in
                                onContentWidthChange(geometry.size.width)
                            }
                    }
                )
                .scaleEffect(digitScale)
                .animation(
                    AnimatedNumberConfig.AnimationTiming.spring.standard,
                    value: digitScale
                )
                .mask(GradientMask(fontSize * 2))
                .clipped()
            }
            .shake(on: shouldShake, amount: 8, shakesPerUnit: 2)
            .animation(.default, value: shouldShake)
        }
    }
    
    private func zIndex(for digit: AnimatedDigit) -> Double {
        if digit.char == "," { return 0 }
        
        if isTransitioningFromZero {
            return (!digit.isNew && digit.char == "0") ? 3 : 2
        }
        
        if isTransitioningToZero {
            return (digit.isNew && digit.char == "0") ? 3 : 2
        }
        
        return digit.isNew ? 2 : 1
    }
}

public struct NumberCountingAnimationView: View {
    @Binding var amount: String
    @Binding var shake: Bool
    
    var maxValue: Decimal
    var minValue: Decimal
    
    var _currency: AnimatedNumberConfig.EAmount.Currency? = .USD
    var _formatter: NumberFormatter = .init()
    var _locale: Locale = .current
    var _fontSize: CGFloat = 17
    var _font: Font = .system(size: 17, weight: .medium)
    var _foregroundColor: Color = .black
    
    public var body: some View {
        Color.clear
            .modifier(
                NumberCountingAnimationModifier(
                    amount: $amount,
                    shake: $shake,
                    maxValue: maxValue,
                    minValue: minValue,
                    currency: _currency,
                    formatter: _formatter,
                    locale: _locale,
                    fontSize: _fontSize,
                    font: _font,
                    foregroundColor: _foregroundColor
                )
            )
    }
}

private struct NumberCountingAnimationModifier: ViewModifier {
    @Binding var amount: String
    @Binding var shake: Bool
    
    let maxValue: Decimal
    let minValue: Decimal
    let currency: AnimatedNumberConfig.EAmount.Currency?
    let formatter: NumberFormatter
    let locale: Locale
    let fontSize: CGFloat
    let font: Font
    let foregroundColor: Color
    
    @State private var animationModel = CurrencyAnimationModel()
    @State private var shouldShake = false
    @State private var contentWidth: CGFloat = 0
    @State private var animatedContainerHeight: CGFloat = 0
    @State private var currentOpacity: Double = 1.0
    @State private var shakeTask: Task<Void, Never>? = nil
    
    func body(content: Content) -> some View {
        NumberCountingView(
            prefix: prefix,
            digits: animationModel.digits,
            oldDigits: animationModel.oldDigits,
            font: font,
            fontSize: fontSize,
            foregroundColor: foregroundColor,
            currentOpacity: currentOpacity,
            digitScale: digitScale,
            shouldShake: shouldShake,
            isTransitioningFromZero: animationModel.isTransitioningFromZero,
            isTransitioningToZero: animationModel.isTransitioningToZero,
            isAddingDecimal: animationModel.isAddingDecimal,
            isDeletingDecimal: animationModel.isDeletingDecimal,
            digitIDs: animationModel.digits.map(\.id),
            onContentWidthChange: { width in
                contentWidth = width
            }
        )
        .onAppear {
            initializeModel()
        }
        .onChange(of: shake) { _, newValue in
            handleShakeChange(newValue)
        }
        .onChange(of: amount) { oldValue, newValue in
            handleAmountChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: digitScale) { _, newScale in
            updateContainerHeight(for: newScale)
        }
    }
    
    private var prefix: String? {
        guard let currency else { return nil }

        switch currency {
        case .USD, .USDC:
            return "$"
        default:
            return nil
        }
    }
    
    private var digitScale: CGFloat {
        guard contentWidth > .zero else { return 1.0 }
        
#if canImport(UIKit)
        let availableWidth = UIScreen.main.bounds.width - 64
#else
        let availableWidth: CGFloat = 320
#endif
        
        if contentWidth <= availableWidth {
            return 1.0
        }
        
        let scale = availableWidth / contentWidth
        return max(0.4, scale)
    }
    
    private var containerHeight: CGFloat {
        fontSize * 1.5
    }
    
    private func initializeModel() {
        animationModel.setValue(
            amount,
            minValue: minValue,
            maxValue: maxValue
        )
        
        currentOpacity = amount.isEmpty ? 0.1 : 1.0
    }
    
    private func handleShakeChange(_ newValue: Bool) {
        guard newValue else { return }
        activateShake()
    }
    
    private func handleAmountChange(oldValue: String, newValue: String) {
        if newValue == "." {
            amount = oldValue
            return
        }
        
        let validationResult = animationModel.isValueValid(
            newValue,
            minValue: minValue,
            maxValue: maxValue
        )
        
        animationModel.setValue(
            newValue,
            minValue: minValue,
            maxValue: maxValue
        )
        
        updateOpacity(oldValue: oldValue, newValue: newValue, isValid: validationResult.0)
        
        guard validationResult.0 else {
            triggerErrorFeedback()
            return
        }
    }
    
    private func triggerErrorFeedback() {
#if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
        
        activateShake()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentOpacity = 0.1
        }
    }
    
    private func updateOpacity(oldValue: String, newValue: String, isValid: Bool) {
        guard isValid else { return }
        
        let animation = Animation.easeInOut(duration: 0.2)
        
        if newValue.isEmpty {
            withAnimation(animation) { currentOpacity = 0.1 }
        } else if oldValue == "0" && newValue != "0" {
            withAnimation(animation) { currentOpacity = 1.0 }
        } else if oldValue != "0" && newValue == "0" {
            withAnimation(animation) { currentOpacity = 0.1 }
        } else {
            withAnimation(animation) { currentOpacity = 1.0 }
        }
    }
    
    private func updateContainerHeight(for scale: CGFloat) {
        withAnimation(
            .spring(
                duration: 0.15,
                bounce: 0
            )
        ) {
            animatedContainerHeight = containerHeight * scale
        }
    }
    
    private func activateShake() {
        shouldShake = true
        shakeTask?.cancel()
        shakeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.1))
            shouldShake = false
            shakeTask = nil
        }
    }
}

public extension NumberCountingAnimationView {
    static func animationStyle(
        _ amount: Binding<String>,
        shake: Binding<Bool>,
        min: Binding<Decimal> = .constant(.leastFiniteMagnitude),
        max: Binding<Decimal> = .constant(.greatestFiniteMagnitude)
    ) -> NumberCountingAnimationView {
        NumberCountingAnimationView(
            amount: amount,
            shake: shake,
            maxValue: max.wrappedValue,
            minValue: min.wrappedValue
        )
    }
    
    func currency(_ newValue: AnimatedNumberConfig.EAmount.Currency?) -> NumberCountingAnimationView {
        var copy = self
        copy._currency = newValue
        return copy
    }
    
    func formatter(_ newValue: NumberFormatter) -> NumberCountingAnimationView {
        var copy = self
        copy._formatter = newValue
        return copy
    }
    
    func locale(_ newValue: Locale) -> NumberCountingAnimationView {
        var copy = self
        copy._locale = newValue
        return copy
    }
    
    func font(_ newValue: Font, size: CGFloat? = nil) -> NumberCountingAnimationView {
        var copy = self
        copy._font = newValue
        if let size { copy._fontSize = size }
        return copy
    }
    
    func foregroundColor(_ newValue: Color) -> NumberCountingAnimationView {
        var copy = self
        copy._foregroundColor = newValue
        return copy
    }
}

public extension View {
    func animationStyle(
        _ amount: Binding<String>,
        shake: Binding<Bool>,
        min: Binding<Decimal> = .constant(.leastFiniteMagnitude),
        max: Binding<Decimal> = .constant(.greatestFiniteMagnitude)
    ) -> NumberCountingAnimationView {
        NumberCountingAnimationView.animationStyle(
            amount,
            shake: shake,
            min: min,
            max: max
        )
    }
    
    func numberCounting(
        _ value: String?,
        step: Double? = nil,
        maxSteps: Int? = nil
    ) -> some View {
        self
    }
}
