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
	func `second observation before timeout cancels the pending idle and keeps state true`() async {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try? await sleeper.waitForSleep()

		await sut.noteObservation()
		try? await sleeper.waitForSleep()

		// Only the leading true has been emitted — the first idle was cancelled
		// before it could fire, and the second timer is still parked.
		#expect(recorder.changes == [true])
	}

	@Test
	func `reset while detecting emits a trailing false and prevents further idle events`() async {
		let (sut, sleeper, recorder) = makeSUT()
		await sut.noteObservation()
		try? await sleeper.waitForSleep()

		await sut.reset()
		await recorder.waitForChangeCount(2)
		#expect(recorder.changes == [true, false])

		// Releasing the cancelled sleeper afterwards must not emit anything.
		sleeper.resumeAll()
		try? await Task.sleep(for: .milliseconds(10))
		#expect(recorder.changes == [true, false])
	}

	@Test
	func `reset while not detecting is silent`() async {
		let (sut, _, recorder) = makeSUT()
		await sut.reset()
		try? await Task.sleep(for: .milliseconds(10))
		#expect(recorder.changes.isEmpty)
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
