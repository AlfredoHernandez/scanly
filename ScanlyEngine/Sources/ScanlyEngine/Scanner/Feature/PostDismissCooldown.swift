//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Content-based suppression window applied after the result sheet is
/// dismissed: the same `rawContent` cannot present the sheet again
/// within the configured window, anchored at the dismissal timestamp.
/// Different content is honored immediately; the window does not
/// extend on each suppressed query.
///
/// Pure value type — callers inject a clock so behaviour is
/// deterministic in tests.
public nonisolated struct PostDismissCooldown: Sendable {
	private let window: TimeInterval
	private let clock: @Sendable () -> Date
	private var lastDismissedContent: String?
	private var lastDismissedAt: Date?

	/// - Parameters:
	///   - window: Suppression length in seconds. Half-open: a query at
	///     exactly `dismissAt + window` is not suppressed. Traps on
	///     negative values.
	///   - clock: Time source — production passes `Date.init`, tests
	///     inject a controllable clock.
	public init(window: TimeInterval, clock: @escaping @Sendable () -> Date) {
		precondition(window >= 0, "Cooldown window must be non-negative; got \(window)")
		self.window = window
		self.clock = clock
	}

	public mutating func recordDismissal(of content: String) {
		lastDismissedContent = content
		lastDismissedAt = clock()
	}

	public func shouldSuppress(_ content: String) -> Bool {
		guard let lastDismissedContent,
		      lastDismissedContent == content,
		      let lastDismissedAt else { return false }
		return clock().timeIntervalSince(lastDismissedAt) < window
	}
}
