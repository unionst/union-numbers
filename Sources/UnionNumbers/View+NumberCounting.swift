//
//  View+NumberCounting.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import Foundation
import SwiftUI
import UnionGradients

private nonisolated struct NumberCountingModifier: AnimatableModifier {
    var value: Double
    let step: Double?
    let maxSteps: Int?

    var animatableData: Double {
        get {
            value
        }
        set {
            value = newValue
        }
    }
    
    func body(
        content: Content
    ) -> some View {
        content
            .hidden()
            .overlay(
                Text("\(Int(value))"
                )
            )
    }
}

private struct ConditionalNumberCountingModifier: ViewModifier {
    let value: Double?
    let step: Double?
    let maxSteps: Int?
    
    @State private var currentValue: Double = 0
    
    func body(
        content: Content
    ) -> some View {
        Group {
            if let target = value {
                content
                    .modifier(
                        NumberCountingModifier(
                            value: currentValue,
                            step: step,
                            maxSteps: maxSteps
                        )
                    )
                    .onAppear {
                        currentValue = target
                    }
                    .onChange(
                        of: value
                    ) {
                        _,
                        newTarget in
                        let resolved = newTarget ?? currentValue
                        withAnimation(
                            AnimatedNumberConfig.AnimationTiming.spring.standard
                        ) {
                            currentValue = resolved
                        }
                    }
            } else {
                content
            }
        }
    }
}

public struct NumberCountingAnimationView: View {
    @Binding var amount: String
    @Binding var shake: Bool
    
    var maxValue: Decimal
    var minValue: Decimal
    
    var _currency: AnimatedNumberConfig.EAmount.Currency = .USD
    var _formatter: NumberFormatter = .init()
    var _locale: Locale = .current
    var _fontSize: CGFloat = 17
    var _font: Font = .system(
        size: 17,
        weight: .medium
    )
    var _foregroundColor: Color = .black
    
    @State private var animationModel = CurrencyAnimationModel()
    @State private var shouldShake: Bool = false
    @State private var contentWidth: CGFloat = 0
    @State private var animatedContainerHeight: CGFloat = 0
    @State private var currentOpacity: Double = 1.0
    
    var prefix: String? {
        switch _currency {
        case .USD:
            return "$"
        case .USDC:
            return "$"
        default:
            return nil
        }
    }
    
    private var digitScale: CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 64
        
        if contentWidth <= availableWidth {
            return 1.0
        }
        
        let scale = availableWidth / contentWidth
        return max(
            0.4,
            scale
        )
    }
    
    private var containerHeight: CGFloat {
        self._fontSize * 1.5
    }
    
    public var body: some View {
        ZStack {
            HStack(
                alignment: .center,
                spacing: 4
            ) {
                HStack(
                    spacing: 0
                ) {
                    if let prefix = prefix {
                        Text(
                            prefix
                        )
                        .font(
                            _font
                        )
                        .foregroundColor(
                            _foregroundColor
                        )
                        .opacity(
                            currentOpacity
                        )
                    }
                    ForEach(
                        animationModel.digits,
                        id: \.id
                    ) { digit in
                        SimplifiedDigitView(
                            digit: digit,
                            oldDigit: animationModel
                                .oldDigits[digit.digitIndex],
                            fontSize: _fontSize,
                            font: _font,
                            color: _foregroundColor,
                            isTransitioningFromZero: animationModel.isTransitioningFromZero,
                            isTransitioningToZero: animationModel.isTransitioningToZero,
                            isAddingDecimal: animationModel.isAddingDecimal,
                            isDeletingDecimal: animationModel.isDeletingDecimal,
                            overallOpacity: currentOpacity
                        )
                        .fixedSize()
                        .zIndex(
                            { () -> Double in
                                if digit.char == "," {
                                    return 0
                                }
                                if animationModel.isTransitioningFromZero {
                                    return (
                                        !digit.isNew && digit.char == "0"
                                    ) ? 3 : 2
                                }
                                if animationModel.isTransitioningToZero {
                                    return (
                                        digit.isNew && digit.char == "0"
                                    ) ? 3 : 2
                                }
                                return digit.isNew ? 2 : 1
                            }()
                        )
                    }
                }
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                contentWidth = geometry.size.width
                            }
                            .onChange(
                                of: geometry.size.width
                            ) {
                                _,
                                newWidth in
                                contentWidth = newWidth
                            }
                            .onChange(
                                of: animationModel.digits
                            ) {
                                _,
                                _ in
                                contentWidth = geometry.size.width
                            }
                    }
                )
                .scaleEffect(
                    digitScale
                )
                .animation(
                    AnimatedNumberConfig.AnimationTiming.spring.standard,
                    value: digitScale
                )
                .mask(
                    GradientMask(
                        _fontSize * 2
                    )
                )
                .clipped()
            }
            .shake(
                on: shouldShake,
                amount: 8,
                shakesPerUnit: 2
            )
            .animation(
                .default,
                value: shouldShake
            )
            .onChange(
                of: shake
            ) {
                _,
                newValue in
                if newValue {
                    shouldShake = true
                    Task { @MainActor in
                        try? await Task
                            .sleep(
                                nanoseconds: 100_000_000
                            )
                        shouldShake = false
                    }
                }
            }
            .onChange(
                of: digitScale
            ) {
                _,
                newScale in
                withAnimation(
                    .spring(
                        duration: 0.15,
                        bounce: 0
                    )
                ) {
                    animatedContainerHeight = containerHeight * newScale
                }
            }
            .onChange(
                of: amount
            ) {
                oldValue,
                newValue in
                if (
                    newValue == "."
                ) {
                    amount = oldValue
                    return
                }
                let (
                    isValid,
                    errorBoundary
                ) = animationModel.isValueValid(
                    newValue,
                    minValue: minValue,
                    maxValue: maxValue
                )
                animationModel
                    .setValue(
                        newValue,
                        minValue: minValue,
                        maxValue: maxValue
                    )
                if !isValid {
                    UINotificationFeedbackGenerator()
                        .notificationOccurred(
                            .error
                        )
                    shouldShake = true
                    Task { @MainActor in
                        try? await Task
                            .sleep(
                                nanoseconds: 100_000_000
                            )
                        shouldShake = false
                    }
                    withAnimation(
                        .easeInOut(
                            duration: 0.2
                        )
                    ) {
                        currentOpacity = 0.1
                    }
                } else if newValue.isEmpty {
                    withAnimation(
                        .easeInOut(
                            duration: 0.2
                        )
                    ) {
                        currentOpacity = 0.1
                    }
                } else if oldValue == "0" && newValue != "0" {
                    withAnimation(
                        .easeInOut(
                            duration: 0.2
                        )
                    ) {
                        currentOpacity = 1.0
                    }
                } else if oldValue != "0" && newValue == "0" {
                    withAnimation(
                        .easeInOut(
                            duration: 0.2
                        )
                    ) {
                        currentOpacity = 0.1
                    }
                } else {
                    withAnimation(
                        .easeInOut(
                            duration: 0.2
                        )
                    ) {
                        currentOpacity = 1
                    }
                }
            }
        }
    }
}

public extension NumberCountingAnimationView {
    static func animationStyle(
        _ amount: Binding<String>,
        shake: Binding<Bool>,
        min: Binding<Decimal> = .constant(
            .leastFiniteMagnitude
        ),
        max: Binding<Decimal> = .constant(
            .greatestFiniteMagnitude
        )
    ) -> NumberCountingAnimationView {
        NumberCountingAnimationView(
            amount: amount,
            shake: shake,
            maxValue: max.wrappedValue,
            minValue: min.wrappedValue
        )
    }
    
    func currency(
        _ newValue: AnimatedNumberConfig.EAmount.Currency
    ) -> NumberCountingAnimationView {
        var copy = self
        copy._currency = newValue
        return copy
    }
    
    func formatter(
        _ newValue: NumberFormatter
    ) -> NumberCountingAnimationView {
        var copy = self
        copy._formatter = newValue
        return copy
    }
    
    func locale(
        _ newValue: Locale
    ) -> NumberCountingAnimationView {
        var copy = self
        copy._locale = newValue
        return copy
    }
    
    func font(
        _ newValue: Font,
        size: CGFloat? = nil
    ) -> NumberCountingAnimationView {
        var copy = self
        copy._font = newValue
        if let size {
            copy._fontSize = size
        }
        return copy
    }
    
    func foregroundColor(
        _ newValue: Color
    ) -> NumberCountingAnimationView {
        var copy = self
        copy._foregroundColor = newValue
        return copy
    }
}

public extension View {
    func animationStyle(
        _ amount: Binding<String>,
        shake: Binding<Bool>,
        min: Binding<Decimal> = .constant(
            .leastFiniteMagnitude
        ),
        max: Binding<Decimal> = .constant(
            .greatestFiniteMagnitude
        )
    ) -> NumberCountingAnimationView {
        NumberCountingAnimationView
            .animationStyle(
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
