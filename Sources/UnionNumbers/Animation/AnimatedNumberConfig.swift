//
//  AnimatedNumberConfig.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.

import Foundation
import SwiftUI

public struct AnimatedNumberConfig {
    enum AnimationTiming {
        static let baseUnit: TimeInterval = 0.05

        static let debounce = Debounce()
        struct Debounce {
            let deletion: TimeInterval = baseUnit * 0.3
            let shortInput: TimeInterval = baseUnit * 0.5
            let longInput: TimeInterval = baseUnit * 0.8
        }

        static let fade = Fade()
        struct Fade {
            let duration: TimeInterval = baseUnit * 3
            let gap: TimeInterval = baseUnit
            var total: TimeInterval { duration * 2 + gap }
        }

        static let spring = Spring()
        struct Spring {
            let standard = Animation.interactiveSpring(
                response: baseUnit * 5,
                dampingFraction: 0.85,
                blendDuration: baseUnit * 3
            )

            let removal = Animation.interactiveSpring(
                response: baseUnit * 6,
                dampingFraction: 0.9,
                blendDuration: baseUnit * 2
            )

            let fast = Animation.interactiveSpring(
                response: baseUnit * 3,
                dampingFraction: 0.9,
                blendDuration: baseUnit * 2
            )

            let commaFade = Animation.linear(duration: baseUnit * 0.5)
        }

        static let transitionReset: TimeInterval = fade.total + baseUnit
    }

    public struct EAmount {
        public var value: Decimal
        public var currency: Currency

        public enum Currency {
            case USD
            case USDC
        }

        public init(value: Decimal, currency: Currency) {
            self.value = value
            self.currency = currency
        }
    }
    
    struct FontOffset {
        static func getOffset(for fontSize: CGFloat) -> CGFloat {
            return fontSize * 2.0
        }
    }
}
