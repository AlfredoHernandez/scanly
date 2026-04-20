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

	/// Number of sleep calls currently parked. Reads are atomic; use
	/// this to assert that cancellations have actually removed waiters
	/// rather than just marked them cancelled.
	var waiterCount: Int {
		state.withLock { $0.waiters.count }
	}

	/// Synchronously blocks until `count` waiters are registered (default:
	/// at least one), so tests can deterministically release after
	/// triggering work that schedules a sleep.
	func waitForSleep(count: Int = 1, timeout: Duration = .seconds(1)) async throws {
		let deadline = ContinuousClock().now.advanced(by: timeout)
		while waiterCount < count {
			if ContinuousClock().now >= deadline {
				throw SleeperTimeout()
			}
			await Task.yield()
		}
	}

	/// Spins until `waiterCount == expected` (typically used after a
	/// cancellation to observe the `onCancel` handler completing and
	/// the cancelled waiter being removed).
	func waitForWaiterCount(_ expected: Int, timeout: Duration = .seconds(1)) async throws {
		let deadline = ContinuousClock().now.advanced(by: timeout)
		while waiterCount != expected {
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
