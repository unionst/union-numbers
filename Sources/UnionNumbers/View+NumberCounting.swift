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

private struct NumberCountingFormatConfig {
    let currency: AnimatedNumberConfig.EAmount.Currency?
    let formatter: NumberFormatter
    let locale: Locale
    let minValue: Decimal
    let maxValue: Decimal
}

private struct NumberCountingAppearance {
    let font: NumberCountingFont
    let foregroundColor: Color
}

private enum NumberCountingLogic {
    static func prefix(for currency: AnimatedNumberConfig.EAmount.Currency?) -> String? {
        guard let currency else { return nil }
        switch currency {
        case .USD, .USDC:
            return "$"
        default:
            return nil
        }
    }
    
    static func availableWidth() -> CGFloat {
#if canImport(UIKit)
        UIScreen.main.bounds.width - 64
#else
        320
#endif
    }
    
    static func digitScale(contentWidth: CGFloat) -> CGFloat {
        let width = availableWidth()
        if contentWidth <= width {
            return 1.0
        }
        let scale = width / contentWidth
        return max(0.4, scale)
    }
    
    static func opacity(oldValue: String, newValue: String) -> Double {
        if newValue.isEmpty { return 0.1 }
        if oldValue == "0" && newValue != "0" {
            return 1.0
        }
        if oldValue != "0" && newValue == "0" {
            return 0.1
        }
        return 1.0
    }
}

private struct NumberCountingFont {
    let fontStyle: Font
    let fontSize: CGFloat
}

private struct NumberCountingDigits {
    let prefix: String?
    let digits: [AnimatedDigit]
    let oldDigits: [Int: AnimatedDigit]
    let digitIDs: [AnimatedDigit.ID]
}

private struct NumberCountingTransitionState {
    let isTransitioningFromZero: Bool
    let isTransitioningToZero: Bool
}

private struct NumberCountingDecimalState {
    let isAddingDecimal: Bool
    let isDeletingDecimal: Bool
}

private struct NumberCountingStyle {
    let foregroundColor: Color
    let currentOpacity: Double
}

private struct NumberCountingMotion {
    let digitScale: CGFloat
    let shouldShake: Bool
}

private struct NumberCountingLayout {
    let onContentWidthChange: (CGFloat) -> Void
}

private struct NumberCountingView: View {
    let font: NumberCountingFont
    let digitsGroup: NumberCountingDigits
    let transitionState: NumberCountingTransitionState
    let decimalState: NumberCountingDecimalState
    let style: NumberCountingStyle
    let motion: NumberCountingMotion
    let layout: NumberCountingLayout
    
    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 4) {
                HStack(spacing: 0) {
                    if let prefix = digitsGroup.prefix {
                        Text(prefix)
                            .font(font.fontStyle)
                            .foregroundColor(style.foregroundColor)
                            .opacity(style.currentOpacity)
                    }
                    
                    ForEach(digitsGroup.digits, id: \.id) { digit in
                        SimplifiedDigitView(
                            digit: digit,
                            oldDigit: digitsGroup.oldDigits[digit.digitIndex],
                            fontSize: font.fontSize,
                            font: font.fontStyle,
                            color: style.foregroundColor,
                            isTransitioningFromZero: transitionState.isTransitioningFromZero,
                            isTransitioningToZero: transitionState.isTransitioningToZero,
                            isAddingDecimal: decimalState.isAddingDecimal,
                            isDeletingDecimal: decimalState.isDeletingDecimal,
                            overallOpacity: style.currentOpacity
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
                                layout.onContentWidthChange(geometry.size.width)
                            }
                            .onChange(of: geometry.size.width) { _, newWidth in
                                layout.onContentWidthChange(newWidth)
                            }
                            .onChange(of: digitsGroup.digitIDs) { _, _ in
                                layout.onContentWidthChange(geometry.size.width)
                            }
                    }
                )
                .scaleEffect(motion.digitScale)
                .animation(
                    AnimatedNumberConfig.AnimationTiming.spring.standard,
                    value: motion.digitScale
                )
                .mask(GradientMask(font.fontSize * 2))
                .clipped()
            }
            .shake(on: motion.shouldShake, amount: 8, shakesPerUnit: 2)
            .animation(.default, value: motion.shouldShake)
        }
    }
    
    private func zIndex(for digit: AnimatedDigit) -> Double {
        if digit.char == "," {
            return 0
        }
        if transitionState.isTransitioningFromZero {
            if !digit.isNew && digit.char == "0" {
                return 3
            } else {
                return 2
            }
        }
        if transitionState.isTransitioningToZero {
            if digit.isNew && digit.char == "0" {
                return 3
            } else {
                return 2
            }
        }
        if digit.isNew {
            return 2
        } else {
            return 1
        }
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
                    format: NumberCountingFormatConfig(
                        currency: _currency,
                        formatter: _formatter,
                        locale: _locale,
                        minValue: minValue,
                        maxValue: maxValue
                    ),
                    appearance: NumberCountingAppearance(
                        font: NumberCountingFont(
                            fontStyle: _font,
                            fontSize: _fontSize
                        ),
                        foregroundColor: _foregroundColor
                    )
                )
            )
    }
}

private struct NumberCountingAnimationModifier: ViewModifier {
    @Binding var amount: String
    @Binding var shake: Bool
    
    let format: NumberCountingFormatConfig
    let appearance: NumberCountingAppearance
    
    @State private var animationModel = CurrencyAnimationModel()
    @State private var shouldShake = false
    @State private var contentWidth: CGFloat = 0
    @State private var animatedContainerHeight: CGFloat = 0
    @State private var currentOpacity: Double = 1.0
    @State private var shakeTask: Task<Void, Never>? = nil
    
    func body(content: Content) -> some View {
        NumberCountingView(
            font: appearance.font,
            digitsGroup: NumberCountingDigits(
                prefix: prefix,
                digits: animationModel.digits,
                oldDigits: animationModel.oldDigits,
                digitIDs: animationModel.digits.map(\.id)
            ),
            transitionState: NumberCountingTransitionState(
                isTransitioningFromZero: animationModel.isTransitioningFromZero,
                isTransitioningToZero: animationModel.isTransitioningToZero
            ),
            decimalState: NumberCountingDecimalState(
                isAddingDecimal: animationModel.isAddingDecimal,
                isDeletingDecimal: animationModel.isDeletingDecimal
            ),
            style: NumberCountingStyle(
                foregroundColor: appearance.foregroundColor,
                currentOpacity: currentOpacity
            ),
            motion: NumberCountingMotion(
                digitScale: digitScale,
                shouldShake: shouldShake
            ),
            layout: NumberCountingLayout(
                onContentWidthChange: { width in
                    contentWidth = width
                }
            )
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
        NumberCountingLogic.prefix(for: format.currency)
    }
    
    private var digitScale: CGFloat {
        contentWidth > .zero ? NumberCountingLogic.digitScale(contentWidth: contentWidth) : 1.0
    }
    
    private var containerHeight: CGFloat {
        appearance.font.fontSize * 1.5
    }
    
    private func initializeModel() {
        animationModel.setValue(
            amount,
            minValue: format.minValue,
            maxValue: format.maxValue
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
        
        let validationResult = animationModel.isValueInBounds(
            newValue,
            minValue: format.minValue,
            maxValue: format.maxValue
        )
        
        animationModel.setValue(
            newValue,
            minValue: format.minValue,
            maxValue: format.maxValue
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
        
        withAnimation(animation) {
            currentOpacity = NumberCountingLogic.opacity(oldValue: oldValue, newValue: newValue)
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
        self.modifier(EmptyModifier())
    }
}
