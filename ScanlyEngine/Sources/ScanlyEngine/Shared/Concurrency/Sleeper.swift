//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Narrow seam around `Task.sleep(for:)` so callers that orchestrate
/// time-based behavior (debounces, idle timers, cooldowns) can be
/// unit-tested without wall-clock waits.
public protocol Sleeper: Sendable {
	/// Suspends for `duration`. Throws `CancellationError` when the
	/// enclosing task is cancelled — matches `Task.sleep(for:)`'s contract
	/// so callers can swap implementations without changing control flow.
	///
	/// Marked `@concurrent` so the suspension always runs off the caller's
	/// actor (typically `@MainActor`). Production callers therefore never
	/// pin the main thread while waiting, and the protocol seam advertises
	/// this guarantee to anyone writing a future conformer.
	@concurrent
	func sleep(for duration: Duration) async throws
}

/// Production `Sleeper` backed by `Task.sleep(for:)`.
public nonisolated struct TaskSleeper: Sleeper {
	public init() {}

	@concurrent
	public func sleep(for duration: Duration) async throws {
		try await Task.sleep(for: duration)
	}
}
