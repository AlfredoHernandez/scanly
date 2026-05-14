//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import ScanlyEngineTestSupport
import Testing

@MainActor
struct LastWriterWinsPusherTests {
	@Test
	func `single push delivers the value to the sink`() async {
		let (sut, sink) = makeSUT()
		sut.push(42)
		await sut.awaitLatest()
		#expect(sink.received == [42])
	}

	@Test
	func `burst of pushes collapses to a single delivery of the final value`() async {
		let (sut, sink) = makeSUT()
		sut.push(1)
		sut.push(2)
		sut.push(3)
		await sut.awaitLatest()
		#expect(sink.received == [3], "Prior pushes must be suppressed via Task.isCancelled")
	}

	@Test
	func `sequential pushes with an await between each deliver every value`() async {
		let (sut, sink) = makeSUT()
		sut.push(10)
		await sut.awaitLatest()
		sut.push(20)
		await sut.awaitLatest()
		sut.push(30)
		await sut.awaitLatest()
		#expect(sink.received == [10, 20, 30])
	}

	@Test
	func `push followed immediately by deinit suppresses delivery`() async throws {
		let sink = SinkSpy<Int>()
		var sut: LastWriterWinsPusher<Int>? = LastWriterWinsPusher(sink: sink.record)
		sut?.push(7)
		// Tearing down before the scheduled task gets a turn should
		// cancel it so the sink is never called.
		sut = nil
		try await Task.sleep(for: .milliseconds(50))
		#expect(sink.received.isEmpty, "Deinit must cancel the pending task before it delivers")
	}

	// MARK: - Helpers

	private func makeSUT() -> (sut: LastWriterWinsPusher<Int>, sink: SinkSpy<Int>) {
		let sink = SinkSpy<Int>()
		let sut = LastWriterWinsPusher(sink: sink.record)
		return (sut, sink)
	}
}

@MainActor
private final class SinkSpy<Value: Sendable> {
	private(set) var received: [Value] = []

	func record(_ value: Value) async {
		received.append(value)
	}
}
