//
//  AnimationQueue.swift
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

actor AnimationQueue {
    private var currentTask: Task<Void, Never>?
    private var pendingValue: String?
    private var isProcessing = false
    private var lastProcessedValue: String?

    @available(macOS 13.0, *)
    func enqueue(_ value: String, apply: @Sendable @escaping (String) async -> Void) async {
        pendingValue = value

        let isDeleting = isDeleting(newValue: value, oldValue: lastProcessedValue)

        guard !isProcessing else { return }

        isProcessing = true

        if !isDeleting {
            currentTask?.cancel()
        }

        let task = Task {
            let debounceTime: Double
            
            if isDeleting {
                debounceTime = AnimatedNumberConfig.AnimationTiming.debounce.deletion
            } else if value.count > 3 {
                debounceTime = AnimatedNumberConfig.AnimationTiming.debounce.longInput
            } else {
                debounceTime = AnimatedNumberConfig.AnimationTiming.debounce.shortInput
            }
            
            do {
                try await Task.sleep(for: .seconds(debounceTime))
            } catch {
                print("sleep failed in AnimationQueue enqueue: \(error)")
            }

            guard !Task.isCancelled else {
                setProcessing(false)
                return
            }

            if let latestValue = getPendingValue() {
                await apply(latestValue)
                setLastProcessedValue(latestValue)
            }

            setProcessing(false)
        }

        currentTask = task
    }

    private func getPendingValue() -> String? {
        pendingValue
    }

    private func setProcessing(_ value: Bool) {
        isProcessing = value
    }

    private func setLastProcessedValue(_ value: String) {
        lastProcessedValue = value
    }

    private func isDeleting(newValue: String, oldValue: String?) -> Bool {
        guard let oldValue else { return false }
        return newValue.count < oldValue.count
    }
}
