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
        let transitionStatus: TransitionStatus
        
        if oldDigit == nil {
            transitionStatus = .increasing
        } else {
            let digitValue = digit.char.wholeNumberValue ?? 0
            let oldDigitValue = oldDigit!.char.wholeNumberValue ?? 0
            
            if digitValue == oldDigitValue {
                transitionStatus = .equal
            } else if digitValue > oldDigitValue {
                transitionStatus = .increasing
            } else {
                transitionStatus = .decreasing
            }
        }
        
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
            let insertionTransition: AnyTransition
            let removalTransition: AnyTransition

            if isAddingDecimal {
                insertionTransition = .offset(y: offset).combined(with: .opacity)
            } else {
                insertionTransition = .offset(y: -offset).combined(with: .opacity)
            }

            if isDeletingDecimal {
                removalTransition = .offset(y: offset).combined(with: .opacity)
            } else {
                removalTransition = .offset(y: -offset).combined(with: .opacity)
            }

            return .asymmetric(
                insertion: insertionTransition,
                removal: removalTransition
            )
        }

        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && digit.char == "0" {
            let insertion = AnyTransition.offset(y: -offset).combined(with: .opacity)
            let removal   = AnyTransition.offset(y: offset).combined(with: .opacity)

            return .asymmetric(insertion: insertion, removal: removal)
        }

        if oldDigit?.char.wholeNumberValue == nil && isTransitioningToZero && !digit.isNew {
            let insertion = AnyTransition.offset(y: offset).combined(with: .opacity)
            let removal   = AnyTransition.offset(y: offset).combined(with: .opacity)

            return .asymmetric(insertion: insertion, removal: removal)
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
                    .opacity(determineOpacity())
                    .contentTransition(.identity)
            } else {
                Text(String(digit.char))
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
