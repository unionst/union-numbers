//
//  AnimationQueue.swift
//  union-numbers
//
//  Created by Vitor Lelis on 8/12/25.
//

import Foundation

/// An actor that manages debounced animation updates for number changes.
actor AnimationQueue {

    // MARK: - Private Properties

    private var currentTask: Task<Void, Never>?
    private var pendingValue: String?
    private var isProcessing = false
    private var lastProcessedValue: String?

    // MARK: - Public Methods

    /// Enqueues a value change with appropriate debouncing.
    /// - Parameters:
    ///   - value: The new value to process.
    ///   - apply: The closure to call with the final value.
    @available(macOS 13.0, iOS 16.0, *)
    func enqueue(_ value: String, apply: @Sendable @escaping (String) async -> Void) async {
        pendingValue = value

        let isDeleting = isDeleting(newValue: value, oldValue: lastProcessedValue)

        guard !isProcessing else { return }

        isProcessing = true

        if !isDeleting {
            currentTask?.cancel()
        }

        let task = Task {
            let debounceTime = debounceTime(for: value, isDeleting: isDeleting)

            do {
                try await Task.sleep(for: .seconds(debounceTime))
            } catch {
                // Task was cancelled, which is expected behavior
            }

            guard !Task.isCancelled else {
                isProcessing = false
                return
            }

            if let latestValue = pendingValue {
                await apply(latestValue)
                lastProcessedValue = latestValue
            }

            isProcessing = false
        }

        currentTask = task
    }

    // MARK: - Private Methods

    private func debounceTime(for value: String, isDeleting: Bool) -> Double {
        if isDeleting {
            return AnimationTiming.Debounce.deletion
        } else if value.count > 3 {
            return AnimationTiming.Debounce.longInput
        } else {
            return AnimationTiming.Debounce.shortInput
        }
    }

    private func isDeleting(newValue: String, oldValue: String?) -> Bool {
        guard let oldValue else { return false }
        return newValue.count < oldValue.count
    }
}
