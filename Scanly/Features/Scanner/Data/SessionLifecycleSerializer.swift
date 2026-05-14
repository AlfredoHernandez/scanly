//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Serializes a fire-and-forget `stop` and an awaitable `start` so a
/// `start` call cannot race ahead of a still-pending `stop`.
///
/// **Why this exists.** `AVFoundationQRScanner.stop()` cannot be `async`
/// (it's invoked from synchronous SwiftUI callbacks and `deinit`), so
/// the implementation wraps `await core.stop()` in a `Task`. A `start`
/// call that immediately follows `await`s the underlying actor
/// directly — one scheduling hop — while the stop has multiple
/// (schedule the task, run its body, then enqueue on the actor). The
/// scheduler frequently lets `start` reach the session actor first,
/// which then suspends on its own permission check; the queued `stop`
/// runs in that suspension window, flips the session's `desiredRunning`
/// flag back to `false`, and `start` resumes only to bail out. The
/// session never starts — symptom: live preview keeps rendering but
/// no metadata callbacks fire and the reticle never turns green.
///
/// The serializer fixes this by tracking the in-flight stop task and
/// awaiting its **completion** at the top of `start()`. The while-loop
/// also picks up a *new* stop scheduled during the drain — without it
/// the race would re-open one level down.
///
/// Reused only inside `AVFoundationQRScanner`. Generic over closures
/// rather than tied to `SessionCore` so the unit tests can drive both
/// branches with synchronous spies instead of standing up a real
/// `AVCaptureSession`.
@MainActor
final class SessionLifecycleSerializer {
	private let onStart: @MainActor () async throws -> Void
	private let onStop: @MainActor () async -> Void
	private var pendingStops: [Task<Void, Never>] = []

	init(
		onStart: @escaping @MainActor () async throws -> Void,
		onStop: @escaping @MainActor () async -> Void,
	) {
		self.onStart = onStart
		self.onStop = onStop
	}

	/// Schedules `onStop` to run. Returns immediately; the actual
	/// stop work executes on a child `Task`. Tracks **every**
	/// outstanding stop, not just the latest — back-to-back stops
	/// (e.g. scenePhase `.inactive` then `.background`) must each
	/// drain before the next start.
	func stop() {
		pendingStops.append(Task { [onStop] in await onStop() })
	}

	/// Awaits every in-flight stop, then invokes `onStart`. The
	/// outer `while` drains stops that were scheduled while we
	/// were already awaiting an earlier batch, so the start
	/// callback only runs once every queued stop has fully
	/// completed.
	func start() async throws {
		while !pendingStops.isEmpty {
			let snapshot = pendingStops
			pendingStops.removeAll()
			for task in snapshot {
				await task.value
			}
		}
		try await onStart()
	}
}
