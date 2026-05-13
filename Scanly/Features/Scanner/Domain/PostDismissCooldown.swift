//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Content-based suppression window applied after the result sheet is
/// dismissed. Per §10.1.3, the same `rawContent` cannot present the
/// sheet again within the configured window (default 2 seconds) anchored
/// at the dismissal timestamp. Different content is honored immediately;
/// the window does not extend on each suppressed query.
///
/// Pure value type — no Foundation timers, no actors. Callers inject a
/// clock so the cooldown is deterministic in tests.
nonisolated struct PostDismissCooldown {
	private let window: TimeInterval
	private let clock: @Sendable () -> Date
	private var lastDismissedContent: String?
	private var lastDismissedAt: Date?

	/// Creates a cooldown with the given suppression window and time source.
	///
	/// - Parameters:
	///   - window: Length in seconds of the post-dismissal suppression
	///     interval. Queries arriving strictly less than this many
	///     seconds after `recordDismissal(of:)` are eligible for
	///     suppression; at exactly `window` seconds the interval is
	///     considered expired (half-open). Must be `>= 0` — a negative
	///     window would invert the suppression check (queries from the
	///     future would suppress), so the initializer traps.
	///   - clock: Time source used by `recordDismissal(of:)` to stamp
	///     the dismissal and by `shouldSuppress(_:)` to measure elapsed
	///     time. Tests inject a controllable clock; production passes
	///     `Date.init` or a wrapped equivalent.
	init(window: TimeInterval, clock: @escaping @Sendable () -> Date) {
		precondition(window >= 0, "Cooldown window must be non-negative; got \(window)")
		self.window = window
		self.clock = clock
	}

	/// Records a dismissal at the current clock time. Subsequent queries
	/// for the same `content` will return `true` from `shouldSuppress(_:)`
	/// for the next `window` seconds.
	mutating func recordDismissal(of content: String) {
		lastDismissedContent = content
		lastDismissedAt = clock()
	}

	/// Returns `true` only when the queried content exactly matches the
	/// just-dismissed content AND the elapsed time since dismissal is
	/// strictly less than the window. Boundary is half-open: a query at
	/// exactly `dismissAt + window` is not suppressed.
	func shouldSuppress(_ content: String) -> Bool {
		guard let lastDismissedContent,
		      lastDismissedContent == content,
		      let lastDismissedAt else { return false }
		return clock().timeIntervalSince(lastDismissedAt) < window
	}
}
