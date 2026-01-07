//
//  AnimatedDigit.swift
//  union-numbers
//
//  Created by Vitor Lelis on 8/12/25.
//

import Foundation

/// Represents a single digit or character in an animated number display.
struct AnimatedDigit: Identifiable, Equatable, Sendable {

    // MARK: - Properties

    let char: Character
    let digitIndex: Int
    let isNew: Bool
    let isZeroTransition: Bool
    let isPlaceholder: Bool
    let isReplacingDigit: Bool

    var id: String {
        "\(digitIndex)-\(char)"
    }

    /// Whether this character is a symbol (not a digit or separator)
    var isSymbol: Bool {
        !char.isNumber && char != "," && char != "."
    }

    // MARK: - Initialization

    init(
        char: Character,
        digitIndex: Int,
        isNew: Bool = false,
        isZeroTransition: Bool = false,
        isPlaceholder: Bool = false,
        isReplacingDigit: Bool = false
    ) {
        self.char = char
        self.digitIndex = digitIndex
        self.isNew = isNew
        self.isZeroTransition = isZeroTransition
        self.isPlaceholder = isPlaceholder
        self.isReplacingDigit = isReplacingDigit
    }

    // MARK: - Equatable

    static func == (lhs: AnimatedDigit, rhs: AnimatedDigit) -> Bool {
        lhs.digitIndex == rhs.digitIndex
            && lhs.char == rhs.char
            && lhs.isPlaceholder == rhs.isPlaceholder
            && lhs.isNew == rhs.isNew
            && lhs.isZeroTransition == rhs.isZeroTransition
            && lhs.isReplacingDigit == rhs.isReplacingDigit
    }
}
