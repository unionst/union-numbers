//
//  AnimatedNumberConfig.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.

import Foundation
import SwiftUI

public struct AnimatedNumberConfig {
    enum AnimationTiming {
        static let debounce = Debounce()
        struct Debounce {
            let deletion: Double = 0.015
            let shortInput: Double = 0.025
            let longInput: Double = 0.04
        }

        static let fade = Fade()
        struct Fade {
            let duration: Double = 0.15
            let gap: Double = 0.05
            var total: Double { duration * 2 + gap }
        }

        static let spring = Spring()
        struct Spring {
            let standard = Animation.interactiveSpring(
                response: 0.25,
                dampingFraction: 0.85,
                blendDuration: 0.15
            )

            let removal = Animation.interactiveSpring(
                response: 0.3,
                dampingFraction: 0.9,
                blendDuration: 0.1
            )

            let fast = Animation.interactiveSpring(
                response: 0.15,
                dampingFraction: 0.9,
                blendDuration: 0.1
            )

            let commaFade = Animation.linear(duration: 0.025)
        }

        static let transitionReset: Double = fade.total + 0.05
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
