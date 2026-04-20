//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import os
import Testing

struct DetectionStateEmitterTests {
	@Test
	func `first observation emits a leading true`() async {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try? await sleeper.waitForSleep()
		#expect(recorder.changes == [true])
	}

	@Test
	func `elapsed idle timeout emits a trailing false`() async {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try? await sleeper.waitForSleep()
		sleeper.resumeAll()
		await recorder.waitForChangeCount(2)
		#expect(recorder.changes == [true, false])
	}

	@Test
	func `second observation before timeout cancels the pending idle and keeps state true`() async throws {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try await sleeper.waitForSleep()

		await sut.noteObservation()
		// The first timer's `.cancel()` drives `ControllableSleeper.onCancel`,
		// which removes the waiter. The second observation registers a fresh
		// one, so exactly one waiter remains — observing this is the deterministic
		// proof that the first idle was cancelled before it could fire.
		try await sleeper.waitForWaiterCount(1)
		#expect(recorder.changes == [true])
	}

	@Test
	func `reset while detecting emits a trailing false and prevents further idle events`() async throws {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try await sleeper.waitForSleep()

		await sut.reset()
		await recorder.waitForChangeCount(2)
		#expect(recorder.changes == [true, false])

		// Reset cancels the sleeper waiter via `.cancel()`, so the waiter
		// count should already be zero. Releasing after that is a no-op.
		try await sleeper.waitForWaiterCount(0)
		sleeper.resumeAll()
		try await Self.yieldMany()
		#expect(recorder.changes == [true, false])
	}

	@Test
	func `reset while not detecting is silent`() async throws {
		let (sut, _, recorder) = makeSUT()
		await sut.reset()
		try await Self.yieldMany()
		#expect(recorder.changes.isEmpty)
	}

	@Test
	func `observation after reset re-emits a fresh leading true`() async throws {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try await sleeper.waitForSleep()
		await sut.reset()
		await recorder.waitForChangeCount(2)
		#expect(recorder.changes == [true, false])

		// A reset fully disarms the emitter; the next observation is a
		// first-detection from the state machine's point of view.
		await sut.noteObservation()
		await recorder.waitForChangeCount(3)
		#expect(recorder.changes == [true, false, true])
	}

	/// Pumps the cooperative scheduler enough times that any pending
	/// actor-hop callback would have fired; used to assert *non-arrival*
	/// of changes without a wall-clock sleep.
	private static func yieldMany(iterations: Int = 20) async throws {
		for _ in 0 ..< iterations {
			await Task.yield()
		}
	}

	// MARK: - Helpers

	private func makeSUT() -> (DetectionStateEmitter, ControllableSleeper, ChangeRecorder) {
		let sleeper = ControllableSleeper()
		let recorder = ChangeRecorder()
		let sut = DetectionStateEmitter(
			idleTimeout: .milliseconds(250),
			sleeper: sleeper,
			onChange: { [recorder] detecting in recorder.record(detecting) },
		)
		return (sut, sleeper, recorder)
	}
}

/// Records `onChange` calls from the emitter. Lock-protected so the
/// test thread and the emitter's actor-hop callbacks don't race.
private final class ChangeRecorder: @unchecked Sendable {
	private let state = OSAllocatedUnfairLock(initialState: [Bool]())

	var changes: [Bool] {
		state.withLock { $0 }
	}

	func record(_ value: Bool) {
		state.withLock { $0.append(value) }
	}

	func waitForChangeCount(_ target: Int, timeout: Duration = .seconds(1)) async {
		let deadline = ContinuousClock().now.advanced(by: timeout)
		while changes.count < target, ContinuousClock().now < deadline {
			await Task.yield()
		}
	}
}
