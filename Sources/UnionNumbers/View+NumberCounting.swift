//
//  View+NumberCounting.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import SwiftUI

private nonisolated struct NumberCountingModifier: AnimatableModifier {
    var value: Double
    let step: Double?
    let maxSteps: Int?

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private var displayValue: Int {
        if let step = step {
            if let maxSteps = maxSteps {
                let steps = min(Int(value / step), maxSteps)
                return Int(Double(steps) * step)
            } else {
                return Int(floor(value / step) * step)
            }
        }
        return Int(value)
    }

    func body(content: Content) -> some View {
        Text("\(displayValue)")
    }
}

private struct ConditionalNumberCountingModifier: ViewModifier {
    let value: Double?
    let step: Double?
    let maxSteps: Int?

    func body(content: Content) -> some View {
        if let value = value {
            content.modifier(
                NumberCountingModifier(
                    value: value,
                    step: step,
                    maxSteps: maxSteps
                )
            )
        } else {
            content
        }
    }
}

public extension View {
    func numberCounting(
        _ value: Double?,
        step: Double? = nil,
        maxSteps: Int? = nil
    ) -> some View {
        self.modifier(
            ConditionalNumberCountingModifier(
                value: value,
                step: step,
                maxSteps: maxSteps
            )
        )
    }

    func numberCounting(
        _ value: Int?,
        step: Double? = nil,
        maxSteps: Int? = nil
    ) -> some View {
        self.modifier(
            ConditionalNumberCountingModifier(
                value: value.map(Double.init),
                step: step,
                maxSteps: maxSteps
            )
        )
    }
}
