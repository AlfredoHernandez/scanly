//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Yields the current task until `condition` returns `true` or `timeout`
/// elapses. Centralizes the "spin-yield against a deadline" pattern that
/// tests use to observe an asynchronous side effect landing on the
/// MainActor (e.g. a `Task`-spawned auto-clear writing back to a
/// `@MainActor` view-model property).
///
/// Throws `WaitUntilTimeout` if the condition does not become true within
/// the budget — the throw fails the test cleanly via Swift Testing's
/// error-reporting path, so callers don't need a follow-up `#expect`.
///
/// Prefer this over an ad-hoc `for _ in 0..<N { await Task.yield() }`
/// loop: a deadline-based budget is less sensitive to CI scheduling
/// jitter than a fixed iteration count.
@MainActor
public func waitUntil(
	timeout: Duration = .seconds(1),
	_ condition: () -> Bool,
) async throws {
	let deadline = ContinuousClock().now.advanced(by: timeout)
	while !condition() {
		if ContinuousClock().now >= deadline {
			throw WaitUntilTimeout()
		}
		await Task.yield()
	}
}

public struct WaitUntilTimeout: Error {
	public init() {}
}
