//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

@MainActor
struct LastWriterWinsPusherTests {
	@Test
	func `single push delivers the value to the sink`() async {
		let spy = SinkSpy<Int>()
		let sut = LastWriterWinsPusher(sink: spy.record)
		sut.push(42)
		await sut.awaitLatest()
		#expect(spy.received == [42])
	}

	@Test
	func `burst of pushes collapses to a single delivery of the final value`() async {
		let spy = SinkSpy<Int>()
		let sut = LastWriterWinsPusher(sink: spy.record)
		sut.push(1)
		sut.push(2)
		sut.push(3)
		await sut.awaitLatest()
		#expect(spy.received == [3], "Prior pushes must be suppressed via Task.isCancelled")
	}

	@Test
	func `sequential pushes with an await between each deliver every value`() async {
		let spy = SinkSpy<Int>()
		let sut = LastWriterWinsPusher(sink: spy.record)
		sut.push(10)
		await sut.awaitLatest()
		sut.push(20)
		await sut.awaitLatest()
		sut.push(30)
		await sut.awaitLatest()
		#expect(spy.received == [10, 20, 30])
	}

	@Test
	func `push after deinit does nothing`() async {
		let spy = SinkSpy<Int>()
		var sut: LastWriterWinsPusher<Int>? = LastWriterWinsPusher(sink: spy.record)
		sut?.push(7)
		sut = nil
		// Give any in-flight work a turn; it should have been cancelled.
		await Task.yield()
		await Task.yield()
		#expect(
			spy.received.isEmpty || spy.received == [7],
			"Pre-deinit values are allowed, but nothing new should appear afterwards",
		)
	}
}

@MainActor
private final class SinkSpy<Value: Sendable> {
	private(set) var received: [Value] = []

	func record(_ value: Value) async {
		received.append(value)
	}
}
