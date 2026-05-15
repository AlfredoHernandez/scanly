//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Owns the "is a code currently in frame?" debounce: after the first
/// observation it emits `true`; after `idleTimeout` elapses with no
/// fresh observation it emits `false`. Extracted out of `SessionCore`
/// so tests can exercise the state machine against a fake sleeper
/// without standing up a real `AVCaptureSession`.
actor DetectionStateEmitter {
	private let sleeper: any Sleeper
	private let idleTimeout: Duration
	private let onChange: @Sendable (Bool) -> Void
	private var debouncer = DetectionDebouncer()
	private var idleTimerTask: Task<Void, Never>?

	init(
		idleTimeout: Duration,
		sleeper: any Sleeper = TaskSleeper(),
		onChange: @escaping @Sendable (Bool) -> Void,
	) {
		self.idleTimeout = idleTimeout
		self.sleeper = sleeper
		self.onChange = onChange
	}

	deinit {
		idleTimerTask?.cancel()
	}

	/// Call once per delivered metadata observation. Emits `true` on the
	/// leading edge and (re)starts the idle timer.
	func noteObservation() {
		idleTimerTask?.cancel()
		if debouncer.noteObservation() {
			onChange(true)
		}
		idleTimerTask = Task { [weak self, sleeper, idleTimeout] in
			do {
				try await sleeper.sleep(for: idleTimeout)
			} catch {
				return
			}
			guard !Task.isCancelled else { return }
			await self?.fireIdleIfNeeded()
		}
	}

	/// Call on session stop. Emits a trailing `false` if we were detecting,
	/// cancels any pending idle timer.
	func reset() {
		idleTimerTask?.cancel()
		idleTimerTask = nil
		if debouncer.reset() {
			onChange(false)
		}
	}

	private func fireIdleIfNeeded() {
		guard debouncer.noteIdleTimeout() else { return }
		onChange(false)
	}
}
