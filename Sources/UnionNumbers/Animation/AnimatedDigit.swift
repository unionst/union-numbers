//
//  AnimatedDigit.swift
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

struct AnimatedDigit: Identifiable, Equatable {
    let char: Character
    let isNew: Bool
    let isZeroTransition: Bool
    let digitIndex: Int
    let isPlaceholder: Bool
    let isReplacingDigit: Bool
    let id: String

    init(
        char: Character,
        digitIndex: Int,
        isNew: Bool = false,
        isZeroTransition: Bool = false,
        isPlaceholder: Bool = false,
        isReplacingDigit: Bool = false,
        isPlaceholderToRealTransition: Bool = false
    ) {
        self.char = char
        self.isNew = isNew
        self.isZeroTransition = isZeroTransition
        self.digitIndex = digitIndex
        self.isPlaceholder = isPlaceholder
        self.isReplacingDigit = isReplacingDigit
        self.id = "\(digitIndex)-\(char)"
    }

    static func == (lhs: AnimatedDigit, rhs: AnimatedDigit) -> Bool {
        return lhs.digitIndex == rhs.digitIndex && lhs.char == rhs.char && lhs.isPlaceholder == rhs.isPlaceholder && lhs.isNew == rhs.isNew && lhs.isZeroTransition == rhs.isZeroTransition && lhs.isReplacingDigit == rhs.isReplacingDigit
    }
}
