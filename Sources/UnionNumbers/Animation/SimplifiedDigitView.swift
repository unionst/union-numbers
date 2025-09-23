//
//  SimplifiedDigitView.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.
//

import SwiftUI

struct SimplifiedDigitView: View, @preconcurrency Equatable {
    let digit: AnimatedDigit
    let oldDigit: AnimatedDigit?
    let fontSize: CGFloat
    let font: Font
    let color: Color
    let isTransitioningFromZero: Bool
    let isTransitioningToZero: Bool
    let isAddingDecimal: Bool
    let isDeletingDecimal: Bool
    let overallOpacity: Double
    
    private func determineOpacity() -> Double {
        if digit.isPlaceholder && digit.digitIndex == 0 && digit.char == "0" {
            return overallOpacity
        }
        if digit.isPlaceholder {
            return 0.1
        }
        return overallOpacity
    }
    
    enum TransitionStatus {
        case increasing
        case decreasing
        case equal
    }
    
    var transitionAction: AnyTransition {
        let transitionStatus: TransitionStatus = {
            if oldDigit == nil {
                return .increasing
            }
            if (digit.char.wholeNumberValue ?? 0) == (oldDigit!.char.wholeNumberValue ?? 0) {
                return .equal
            }
            return (digit.char.wholeNumberValue ?? 0) > (oldDigit!.char.wholeNumberValue ?? 0) ? .increasing : .decreasing
        }()
        
        if transitionStatus == .equal {
            return .identity
        }

        let isIncreasing: Bool = transitionStatus == .increasing

        if digit.char == "," {
            return AnyTransition.opacity.animation(AnimatedNumberConfig.AnimationTiming.spring.commaFade)
        }
        if digit.char == "." {
            return .opacity
        }
    
        let offset = AnimatedNumberConfig.FontOffset.getOffset(for: fontSize);
        if digit.isPlaceholder {
            return .asymmetric(
                insertion: isAddingDecimal
                ?
                    .offset(
                        y: offset
                    )
                    .combined(
                        with: .opacity
                    )
                :
                        .offset(
                            y: offset * -1
                        )
                        .combined(
                            with: .opacity
                        ),
                removal: isDeletingDecimal
                ?
                    .offset(
                        y: offset
                    )
                    .combined(
                        with: .opacity
                    )
                :
                        .offset(
                            y: offset * -1
                        )
                        .combined(
                            with: .opacity
                        )
            )
        }
        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && digit.char == "0" {
            return .asymmetric(
                insertion: .offset(y: offset * -1)
                    .combined(with: .opacity),
                removal: .offset(y: offset)
                    .combined(with: .opacity)
            )
        }
        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && !digit.isNew {
            return .asymmetric(
                insertion: .offset(y: offset)
                    .combined(with: .opacity),
                removal: .offset(y: offset)
                    .combined(with: .opacity)
            )
        }

        // This has a bug where sometimes the `removal` and `insertion` will be fired together
        // It's super easy to see it using this code:
        // return .asymmetric(insertion: .scale(scale: isIncreasing ? 2.0 : 0.2 ), removal: .identity)
        return .asymmetric(
            insertion: .offset(y: isIncreasing ? offset : offset * -1).combined(with: .opacity),
            removal: .offset(y: isIncreasing ? offset :  offset * -1).combined(with: .opacity)
        )
    }
    
    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                Text(String(digit.char))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(determineOpacity())
                    .contentTransition(.identity)
            } else {
                Text(String(digit.char))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(determineOpacity())
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.1), value: fontSize)
        .transition(transitionAction)
    }

    static func == (lhs: SimplifiedDigitView, rhs: SimplifiedDigitView) -> Bool {
        return lhs.digit == rhs.digit && lhs.overallOpacity == rhs.overallOpacity && rhs.oldDigit == lhs.oldDigit
    }
}
