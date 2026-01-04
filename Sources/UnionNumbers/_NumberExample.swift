//
//  _NumberExample.swift
//  union-numbers
//
//  Created by Ben Sage on 8/19/25.
//

import SwiftUI

@available(macOS 14.0, iOS 17.0, *)
public struct _NumberExample: View {
    @State private var price = 50.0

    public init() {}

    public var body: some View {
        VStack(spacing: 32) {
            AnimatedNumber(value: $price, in: 0...100, format: .currency(code: "USD"))
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()

            HStack(spacing: 16) {
                Button("-$10") { price -= 10 }
                Button("-$1") { price -= 1 }
                Button("+$1") { price += 1 }
                Button("+$10") { price += 10 }
            }
            .buttonStyle(.bordered)

            Text("Try going below $0 or above $100")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    if #available(macOS 14.0, iOS 17.0, *) {
        _NumberExample()
    }
}
