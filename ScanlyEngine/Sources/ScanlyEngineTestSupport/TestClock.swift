//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Deterministic clock for tests. Backs the `@Sendable () -> Date`
/// closure that production code (e.g. `ScannerViewModel`) accepts at
/// initialization, while letting tests advance time at will.
///
/// Use `clock.now` (the unbound method) as the closure: e.g.
/// `makeSUT(clock: clock.now)`. Then call `clock.advance(by:)` to
/// move time forward between assertions.
public final class TestClock: @unchecked Sendable {
	private let lock = NSLock()
	private var current: Date

	/// The non-epoch default (2023-11-14 UTC) keeps `advance(by: negative)`
	/// safe from underflowing the Date range — convenient when tests want
	/// to model a clock that was running before the test started.
	public init(start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
		current = start
	}

	/// Returns the clock's current time. Pass `clock.now` (the unbound
	/// method reference) as the `@Sendable () -> Date` argument that
	/// production code accepts at initialization.
	public func now() -> Date {
		lock.lock()
		defer { lock.unlock() }
		return current
	}

	/// Moves the clock forward (or backward, for negative values) by the
	/// given number of seconds. Subsequent calls to `now()` reflect the
	/// new time. Tests use this to step across timing thresholds (e.g.
	/// the post-dismiss cooldown window).
	public func advance(by seconds: TimeInterval) {
		lock.lock()
		defer { lock.unlock() }
		current = current.addingTimeInterval(seconds)
	}
}
