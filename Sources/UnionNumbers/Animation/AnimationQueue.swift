//
//  AnimationQueue.swift
//  union-animated-number
//
//  Created by Vitor Lelis on 8/12/25.
//

import CoreText
import Foundation
import SwiftUI
import UIKit
import UnionGradients
import UnionShake

actor AnimationQueue {
    private var currentTask: Task<Void, Never>?
    private var pendingValue: String?
    private var isProcessing = false
    private var lastProcessedValue: String?

    func enqueue(_ value: String, apply: @Sendable @escaping (String) async -> Void) async {
        pendingValue = value

        let isDeleting = (lastProcessedValue?.count ?? 0) > value.count

        guard !isProcessing else { return }

        isProcessing = true

        if !isDeleting {
            currentTask?.cancel()
        }

        let task = Task {
            let debounceTime: UInt64 =
                isDeleting
                ? AnimatedNumberConfig.AnimationTiming.debounce.deletion.nanos
                : (value.count > 3
                    ? AnimatedNumberConfig.AnimationTiming.debounce.longInput.nanos
                    : AnimatedNumberConfig.AnimationTiming.debounce.shortInput.nanos)
            try? await Task.sleep(nanoseconds: debounceTime)

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
}

extension TimeInterval {
    var nanos: UInt64 { UInt64(self * 1_000_000_000) }
}
