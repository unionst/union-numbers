//
//  _NumberExample.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import SwiftUI

@available(macOS 14.0, iOS 17.0, *)
public struct _NumberExample: View {
    @AppStorage("numberExample.price") private var price = 0.0
    @AppStorage("numberExample.inputString") private var inputString = "0"
    @AppStorage("numberExample.monospacedDigit") private var monospacedDigit = true
    @AppStorage("numberExample.currencyCode") private var currencyCode = "USD"
    @AppStorage("numberExample.localeId") private var localeId = "en_US"
    @State private var shakeTrigger = 0

    private let currencies = ["None", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY"]
    private let locales: [(id: String, name: String)] = [
        ("en_US", "US"),
        ("en_GB", "UK"),
        ("de_DE", "DE"),
        ("fr_FR", "FR"),
        ("ja_JP", "JP"),
        ("zh_CN", "CN"),
        ("ar_SA", "AR"),
    ]

    private var locale: Locale { Locale(identifier: localeId) }

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Group {
                if currencyCode == "None" {
                    AnimatedNumber(value: $price, in: 0...100_000, format: .number.locale(locale))
                } else {
                    AnimatedNumber(
                        value: $price,
                        in: 0...100_000,
                        format: .currency(code: currencyCode).locale(locale)
                    )
                }
            }
            .font(
                monospacedDigit
                    ? .system(size: 48, weight: .bold).monospacedDigit()
                    : .system(size: 48, weight: .bold)
            )
            .shakeTrigger(shakeTrigger)
            .frame(maxWidth: .infinity)

            randomJumpButtons

            Picker("Currency", selection: $currencyCode) {
                ForEach(currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Picker("Locale", selection: $localeId) {
                ForEach(locales, id: \.id) { locale in
                    Text(locale.name).tag(locale.id)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Toggle("Monospaced Digit", isOn: $monospacedDigit)
                .padding(.horizontal)

            Spacer()

            keypad
        }
        .padding()
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = row * 3 + col
                        keypadButton(String(digit)) { appendDigit(String(digit)) }
                    }
                }
            }
            HStack(spacing: 12) {
                keypadButton(".") { appendDecimal() }
                keypadButton("0") { appendDigit("0") }
                keypadButton("⌫") { deleteLastCharacter() }
            }
            HStack(spacing: 12) {
                keypadButton("C", color: .red) { clear() }
            }
        }
    }

    private func keypadButton(
        _ title: String,
        color: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(color)
                .frame(width: 72, height: 56)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        let newString = inputString == "0" ? digit : inputString + digit
        if let value = Double(newString), value <= 100_000 {
            inputString = newString
            price = value
        } else {
            shakeTrigger += 1
        }
    }

    private func appendDecimal() {
        if !inputString.contains(".") {
            inputString += "."
        }
    }

    private func deleteLastCharacter() {
        if inputString == "0" {
            shakeTrigger += 1
            return
        }
        if inputString.count > 1 {
            inputString.removeLast()
        } else {
            inputString = "0"
        }
        if let value = Double(inputString) {
            price = value
        }
    }

    private func clear() {
        inputString = "0"
        price = 0
    }

    private var randomJumpButtons: some View {
        VStack(spacing: 8) {
            Text("Random Jumps")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("±1") { jumpBy(.ones) }
                Button("±10") { jumpBy(.tens) }
                Button("±100") { jumpBy(.hundreds) }
                Button("±1K") { jumpBy(.thousands) }
                Button("Random") { jumpBy(.random) }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    private enum JumpType {
        case ones, tens, hundreds, thousands, random
    }

    private func jumpBy(_ type: JumpType) {
        let newValue: Double
        switch type {
        case .ones:
            let delta = Double(Int.random(in: 1...9))
            newValue = Bool.random() ? price + delta : max(0, price - delta)
        case .tens:
            let delta = Double(Int.random(in: 1...9) * 10)
            newValue = Bool.random() ? price + delta : max(0, price - delta)
        case .hundreds:
            let delta = Double(Int.random(in: 1...9) * 100)
            newValue = Bool.random() ? price + delta : max(0, price - delta)
        case .thousands:
            let delta = Double(Int.random(in: 1...9) * 1000)
            newValue = Bool.random() ? price + delta : max(0, price - delta)
        case .random:
            // Jump to a completely random value in range
            newValue = Double(Int.random(in: 0...100_000))
        }

        let clampedValue = max(0, min(100_000, newValue))
        price = clampedValue
        inputString = formatInputString(clampedValue)
    }

    private func formatInputString(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        } else {
            return String(value)
        }
    }
}

#Preview {
    if #available(macOS 14.0, iOS 17.0, *) {
        _NumberExample()
    }
}
