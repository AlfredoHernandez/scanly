//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import ScanlyEngineTestSupport
import Testing

@MainActor
struct SessionLifecycleSerializerTests {
	@Test
	func `start invokes onStart when no stop is pending`() async throws {
		let lifecycle = LifecycleSpy()
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		try await sut.start()

		#expect(lifecycle.events == [.startEnded])
	}

	@Test
	func `stop schedules onStop without blocking the caller`() async throws {
		let lifecycle = LifecycleSpy()
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		sut.stop()

		try await waitUntil { lifecycle.events == [.stopBegan, .stopEnded] }
	}

	@Test
	func `start awaits a pending stop before invoking onStart`() async throws {
		// Regression test for the original race: `AVFoundationQRScanner.stop()`
		// wrapped `await core.stop()` in a `Task`, while `start()` awaited
		// the actor directly. The direct path had fewer scheduling hops,
		// so the scheduler frequently let start's actor message arrive
		// before stop's — start then suspended on permission, stop ran
		// in the gap and flipped `desiredRunning` off, and start bailed.
		// The serializer must guarantee stop's full completion happens
		// before onStart is invoked.
		let lifecycle = LifecycleSpy()
		lifecycle.holdStop = true
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		sut.stop()
		try await waitUntil { lifecycle.events == [.stopBegan] }

		let startTask = Task { try await sut.start() }
		// Give the scheduler several chances to run onStart out of order
		// if the serializer weren't enforcing the dependency.
		for _ in 0 ..< 20 {
			await Task.yield()
		}
		#expect(lifecycle.events == [.stopBegan], "start must not run while stop is still in flight")

		lifecycle.releaseStops()
		try await startTask.value

		#expect(lifecycle.events == [.stopBegan, .stopEnded, .startEnded])
	}

	@Test
	func `start awaits a stop scheduled while draining a prior stop`() async throws {
		// Edge case: a second stop arrives while start is already
		// awaiting the first one. Without the drain loop the second
		// stop would race with onStart and the bug would re-open one
		// layer down. Two stops can run concurrently while parked,
		// so the only deterministic invariant is "every stop fully
		// completes before onStart runs."
		let lifecycle = LifecycleSpy()
		lifecycle.holdStop = true
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		sut.stop()
		try await waitUntil { lifecycle.events == [.stopBegan] }

		let startTask = Task { try await sut.start() }
		try await waitUntil { lifecycle.stopWaiterCount == 1 }

		sut.stop()
		try await waitUntil { lifecycle.events.count(where: { $0 == .stopBegan }) == 2 }

		lifecycle.releaseStops()
		try await startTask.value

		#expect(lifecycle.events.last == .startEnded, "onStart must run after every queued stop")
		#expect(lifecycle.events.count(where: { $0 == .stopBegan }) == 2)
		#expect(lifecycle.events.count(where: { $0 == .stopEnded }) == 2)
	}

	@Test
	func `start awaits every back-to-back stop scheduled before it`() async throws {
		// Production scenario: scenePhase transitions can fire
		// `.inactive` then `.background` in rapid succession, each
		// invoking `stop()` before any `start()`. The serializer
		// must await **both** — tracking only the latest would
		// leave the earlier stop's actor message racing with start.
		let lifecycle = LifecycleSpy()
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		sut.stop()
		sut.stop()
		try await sut.start()

		#expect(lifecycle.events.last == .startEnded)
		#expect(lifecycle.events.count(where: { $0 == .stopEnded }) == 2)
	}

	@Test
	func `start propagates errors from onStart`() async {
		let lifecycle = LifecycleSpy()
		lifecycle.startError = anyError()
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		await #expect(throws: NSError.self) {
			try await sut.start()
		}
	}

	@Test
	func `start awaits a pending stop even when onStart will throw`() async throws {
		// Stop must drain regardless of how start finishes; otherwise
		// a failed start could leak a pending-stop reference that the
		// next start drains pointlessly.
		let lifecycle = LifecycleSpy()
		lifecycle.startError = anyError()
		lifecycle.holdStop = true
		let sut = SessionLifecycleSerializer(onStart: lifecycle.start, onStop: lifecycle.stop)

		sut.stop()
		try await waitUntil { lifecycle.events == [.stopBegan] }

		let startTask = Task { try await sut.start() }
		lifecycle.releaseStops()

		await #expect(throws: NSError.self) {
			try await startTask.value
		}
		#expect(lifecycle.events == [.stopBegan, .stopEnded])
	}
}

// MARK: - Helpers

@MainActor
private final class LifecycleSpy {
	enum Event: Equatable {
		case startEnded
		case stopBegan
		case stopEnded
	}

	private(set) var events: [Event] = []
	var startError: Error?
	var holdStop = false
	private var stopGate: [CheckedContinuation<Void, Never>] = []

	var stopWaiterCount: Int {
		stopGate.count
	}

	func start() async throws {
		if let startError {
			throw startError
		}
		events.append(.startEnded)
	}

	func stop() async {
		events.append(.stopBegan)
		if holdStop {
			await withCheckedContinuation { stopGate.append($0) }
		}
		events.append(.stopEnded)
	}

	func releaseStops() {
		let gate = stopGate
		stopGate.removeAll()
		for continuation in gate {
			continuation.resume()
		}
	}
}
