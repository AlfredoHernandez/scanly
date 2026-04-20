//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Coalesces rapid-fire writes into one trailing delivery to `sink`:
/// if `push` is called several times before the prior task starts,
/// only the most recent value is seen by the sink — the earlier tasks
/// observe the cancellation and exit without calling through.
///
/// Used by `AVFoundationQRScanner` for ROI / focus / zoom pushes, where
/// a pinch, tap burst, or layout storm can emit many updates per frame
/// and the device only cares about the final value.
@MainActor
final class LastWriterWinsPusher<Value: Sendable> {
	private var latest: Value?
	private var task: Task<Void, Never>?
	private let sink: @MainActor (Value) async -> Void

	init(sink: @escaping @MainActor (Value) async -> Void) {
		self.sink = sink
	}

	func push(_ value: Value) {
		latest = value
		task?.cancel()
		task = Task { [weak self] in
			guard let self else { return }
			// `cancel()` is marked synchronously on the prior task, but
			// that task still runs. Short-circuit here so bursts don't
			// deliver a trailing value multiple times.
			if Task.isCancelled { return }
			guard let value = latest else { return }
			await sink(value)
		}
	}

	/// Awaits completion of the most recently scheduled push. For tests
	/// only — production callers never observe individual deliveries.
	func awaitLatest() async {
		await task?.value
	}

	deinit {
		task?.cancel()
	}
}
