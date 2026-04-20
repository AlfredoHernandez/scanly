//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import os

/// Test double that parks each `sleep(for:)` call on a continuation and
/// releases them on demand. Honors task cancellation so idle-timer
/// callers that cancel their own task see `CancellationError` just
/// like they would against the real `Task.sleep`.
final class ControllableSleeper: Sleeper, @unchecked Sendable {
	struct Call: Equatable {
		let id: UUID
		let duration: Duration
	}

	private let state = OSAllocatedUnfairLock(
		initialState: State(nextID: 0, waiters: [:]),
	)

	private struct State {
		var nextID: Int
		var waiters: [UUID: CheckedContinuation<Void, Error>]
	}

	/// Synchronously blocks until at least one waiter is registered, so
	/// tests can deterministically release after triggering work that
	/// schedules a sleep.
	func waitForSleep(timeout: Duration = .seconds(1)) async throws {
		let deadline = ContinuousClock().now.advanced(by: timeout)
		while state.withLock(\.waiters.isEmpty) {
			if ContinuousClock().now >= deadline {
				throw SleeperTimeout()
			}
			await Task.yield()
		}
	}

	func resumeAll() {
		let pending = state.withLock { state -> [CheckedContinuation<Void, Error>] in
			let values = Array(state.waiters.values)
			state.waiters.removeAll()
			return values
		}
		for waiter in pending {
			waiter.resume()
		}
	}

	func sleep(for _: Duration) async throws {
		let id = UUID()
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				state.withLock { state in
					state.waiters[id] = continuation
				}
			}
		} onCancel: { [state] in
			let cancelled = state.withLock { $0.waiters.removeValue(forKey: id) }
			cancelled?.resume(throwing: CancellationError())
		}
	}

	struct SleeperTimeout: Error {}
}
