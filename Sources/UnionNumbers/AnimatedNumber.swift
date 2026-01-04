//
//  AnimatedNumber.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Environment Keys

private struct HapticFeedbackKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct ShakeTriggerKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var animatedNumberHapticFeedback: Bool {
        get { self[HapticFeedbackKey.self] }
        set { self[HapticFeedbackKey.self] = newValue }
    }

    var animatedNumberShakeTrigger: Int {
        get { self[ShakeTriggerKey.self] }
        set { self[ShakeTriggerKey.self] = newValue }
    }
}

// MARK: - AnimatedNumber

/// A SwiftUI view that displays a number with smooth digit-by-digit animations.
///
/// `AnimatedNumber` provides slot-machine style transitions when numeric values change.
/// Each digit animates independently, sliding up or down based on whether the value
/// increased or decreased.
///
/// ```swift
/// // Basic display
/// AnimatedNumber(count)
///     .font(.system(size: 48, weight: .bold))
///
/// // With currency formatting
/// AnimatedNumber(price, format: .currency(code: "USD"))
///     .font(.system(size: 48))
///
/// // With bounds validation (rejects out-of-range values)
/// AnimatedNumber(value: $price, in: 0...1000, format: .currency(code: "USD"))
///     .font(.system(size: 48))
/// ```
@available(macOS 14.0, iOS 17.0, *)
public struct AnimatedNumber<F: FormatStyle>: View where F.FormatInput == Double, F.FormatOutput == String {

    // MARK: - Properties

    private let format: F
    private let bounds: ClosedRange<Double>?
    private let binding: Binding<Double>?
    private let textBinding: Binding<String>?
    private let staticValue: Double?
    private let staticText: String?

    @State private var model = NumberAnimationModel()
    @State private var contentWidth: CGFloat = 0
    @State private var measuredFontSize: CGFloat = 17
    @State private var lastValidValue: Double = 0
    @State private var lastValidText: String = "0"
    @State private var shakeCounter: Int = 0

    @Environment(\.animatedNumberHapticFeedback) private var hapticFeedbackEnabled
    @Environment(\.animatedNumberShakeTrigger) private var externalShakeTrigger

    // MARK: - Computed

    private var currentValue: Double {
        if let textBinding {
            return Double(textBinding.wrappedValue) ?? 0
        }
        if let staticText {
            return Double(staticText) ?? 0
        }
        return binding?.wrappedValue ?? staticValue ?? 0
    }

    private var currentInputText: String? {
        textBinding?.wrappedValue ?? staticText
    }

    private var formattedValue: String {
        format.format(currentValue)
    }

    // MARK: - Initializers (Display Only - Numeric)

    /// Creates an animated number display.
    public init(_ value: Double, format: F) {
        self.format = format
        self.bounds = nil
        self.binding = nil
        self.textBinding = nil
        self.staticValue = value
        self.staticText = nil
    }

    /// Creates an animated number display from an integer.
    public init(_ value: Int, format: F) {
        self.init(Double(value), format: format)
    }

    /// Creates an animated number display from a Decimal.
    public init(_ value: Decimal, format: F) {
        self.init(NSDecimalNumber(decimal: value).doubleValue, format: format)
    }

    // MARK: - Initializers (Display Only - String)

    /// Creates an animated number display from a string.
    ///
    /// Use this initializer when you want automatic placeholder detection.
    /// Decimal digits that appear in the formatted output but weren't in the
    /// input string are shown as placeholders (grayed out).
    ///
    /// - Parameters:
    ///   - text: The raw input string (e.g., "1.2").
    ///   - format: The format style to use.
    public init(_ text: String, format: F) {
        self.format = format
        self.bounds = nil
        self.binding = nil
        self.textBinding = nil
        self.staticValue = nil
        self.staticText = text
    }

    /// Creates an animated number display from a string binding.
    ///
    /// Use this initializer for keypad-style input with automatic placeholder detection.
    ///
    /// - Parameters:
    ///   - text: A binding to the raw input string.
    ///   - format: The format style to use.
    public init(text: Binding<String>, format: F) {
        self.format = format
        self.bounds = nil
        self.binding = nil
        self.textBinding = text
        self.staticValue = nil
        self.staticText = nil
    }

    // MARK: - Initializers (Bounded - Numeric)

    /// Creates an animated number with bounds validation.
    ///
    /// When the value goes outside the specified range, it reverts to the last valid value
    /// and triggers a shake animation with haptic feedback.
    ///
    /// - Parameters:
    ///   - value: A binding to the numeric value.
    ///   - bounds: The allowed range for the value.
    ///   - format: The format style to use.
    public init(value: Binding<Double>, in bounds: ClosedRange<Double>, format: F) {
        self.format = format
        self.bounds = bounds
        self.binding = value
        self.textBinding = nil
        self.staticValue = nil
        self.staticText = nil
    }

    /// Creates an animated number with bounds validation from an integer binding.
    public init(value: Binding<Int>, in bounds: ClosedRange<Int>, format: F) {
        self.format = format
        self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound)
        self.binding = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0) }
        )
        self.textBinding = nil
        self.staticValue = nil
        self.staticText = nil
    }

    // MARK: - Initializers (Bounded - String)

    /// Creates an animated number with bounds validation from a string binding.
    ///
    /// Combines keypad-style input with bounds validation and automatic placeholder detection.
    ///
    /// - Parameters:
    ///   - text: A binding to the raw input string.
    ///   - bounds: The allowed range for the value.
    ///   - format: The format style to use.
    public init(text: Binding<String>, in bounds: ClosedRange<Double>, format: F) {
        self.format = format
        self.bounds = bounds
        self.binding = nil
        self.textBinding = text
        self.staticValue = nil
        self.staticText = nil
    }

    // MARK: - Body

    public var body: some View {
        AnimatedNumberView(
            digits: model.digits,
            oldDigits: model.oldDigits,
            fontSize: measuredFontSize,
            isTransitioningFromZero: model.isTransitioningFromZero,
            isTransitioningToZero: model.isTransitioningToZero,
            isAddingDecimal: model.isAddingDecimal,
            isDeletingDecimal: model.isDeletingDecimal,
            isIncreasing: model.isIncreasing,
            scale: computedScale,
            shakeCounter: shakeCounter,
            onContentWidthChange: { contentWidth = $0 }
        )
        .background {
            Text("0")
                .hidden()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    measuredFontSize = newHeight
                }
        }
        .onAppear {
            lastValidValue = currentValue
            lastValidText = currentInputText ?? ""
            model.setValue(formattedValue, rawValue: currentValue, inputText: currentInputText)
        }
        .onChange(of: currentValue) { oldValue, newValue in
            handleValueChange(from: oldValue, to: newValue)
        }
        .onChange(of: formattedValue) { _, newFormatted in
            model.setValue(newFormatted, rawValue: currentValue, inputText: currentInputText)
        }
        .onChange(of: currentInputText) { _, newText in
            model.setValue(formattedValue, rawValue: currentValue, inputText: newText)
        }
        .onChange(of: externalShakeTrigger) { _, _ in
            triggerBoundsError()
        }
    }

    // MARK: - Private Methods

    private func handleValueChange(from oldValue: Double, to newValue: Double) {
        // Check bounds if we have them
        if let bounds {
            if !bounds.contains(newValue) {
                // Out of bounds - reject and shake
                if let binding {
                    binding.wrappedValue = lastValidValue
                } else if let textBinding {
                    textBinding.wrappedValue = lastValidText
                }
                triggerBoundsError()
                return
            }
        }

        // Valid value - update
        lastValidValue = newValue
        lastValidText = currentInputText ?? ""
        model.setValue(format.format(newValue), rawValue: newValue, inputText: currentInputText)
    }

    private func triggerBoundsError() {
        // Haptic feedback
        if hapticFeedbackEnabled {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }

        // Shake animation
        shakeCounter += 1
    }

    private var computedScale: CGFloat {
        guard contentWidth > 0 else { return 1.0 }
        let availableWidth = Self.availableWidth
        guard contentWidth > availableWidth else { return 1.0 }
        return max(0.4, availableWidth / contentWidth)
    }

    private static var availableWidth: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.bounds.width - 64
        #else
        320
        #endif
    }
}

// MARK: - Convenience Initializers (Default Format)

@available(macOS 14.0, iOS 17.0, *)
public extension AnimatedNumber where F == FloatingPointFormatStyle<Double> {
    /// Creates an animated number display with default formatting.
    init(_ value: Double) {
        self.init(value, format: .number)
    }

    /// Creates an animated number display from an integer.
    init(_ value: Int) {
        self.init(Double(value), format: .number)
    }

    /// Creates an animated number display from a Decimal.
    init(_ value: Decimal) {
        self.init(NSDecimalNumber(decimal: value).doubleValue, format: .number)
    }

    /// Creates an animated number display from a string with default formatting.
    init(_ text: String) {
        self.init(text, format: .number)
    }

    /// Creates an animated number from a string binding with default formatting.
    init(text: Binding<String>) {
        self.init(text: text, format: .number)
    }

    /// Creates an animated number with bounds validation.
    init(value: Binding<Double>, in bounds: ClosedRange<Double>) {
        self.init(value: value, in: bounds, format: .number)
    }

    /// Creates an animated number with bounds validation from an integer binding.
    init(value: Binding<Int>, in bounds: ClosedRange<Int>) {
        self.init(value: value, in: bounds, format: .number)
    }

    /// Creates an animated number from a string binding with bounds validation.
    init(text: Binding<String>, in bounds: ClosedRange<Double>) {
        self.init(text: text, in: bounds, format: .number)
    }
}

// MARK: - View Modifier

@available(macOS 14.0, iOS 17.0, *)
public extension View {
    /// Enables or disables haptic feedback when bounds are exceeded.
    ///
    /// When an `AnimatedNumber` with bounds receives an out-of-range value,
    /// it will shake. By default, it also triggers haptic feedback.
    /// Use this modifier to disable the haptic.
    ///
    /// ```swift
    /// AnimatedNumber(value: $price, in: 0...100)
    ///     .hapticFeedback(false)
    /// ```
    func hapticFeedback(_ enabled: Bool) -> some View {
        environment(\.animatedNumberHapticFeedback, enabled)
    }

    /// Triggers a shake animation with haptic feedback when the value changes.
    ///
    /// Increment this value to trigger a shake animation, useful for external
    /// validation like a custom keypad rejecting invalid input.
    ///
    /// ```swift
    /// @State private var shakeTrigger = 0
    ///
    /// AnimatedNumber(value: $price, in: 0...100)
    ///     .shakeTrigger(shakeTrigger)
    ///
    /// // Later, to trigger shake:
    /// shakeTrigger += 1
    /// ```
    func shakeTrigger(_ trigger: Int) -> some View {
        environment(\.animatedNumberShakeTrigger, trigger)
    }
}
