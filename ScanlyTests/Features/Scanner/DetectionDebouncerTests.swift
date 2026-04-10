//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Testing

struct DetectionDebouncerTests {
	@Test
	func `initial state is not detecting`() {
		let sut = DetectionDebouncer()
		#expect(sut.isDetecting == false)
	}

	@Test
	func `first observation emits a true edge`() {
		var sut = DetectionDebouncer()
		#expect(sut.noteObservation() == true)
		#expect(sut.isDetecting == true)
	}

	@Test
	func `repeated observations within the same detection window do not re-emit`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		#expect(sut.noteObservation() == false)
		#expect(sut.noteObservation() == false)
	}

	@Test
	func `idle timeout after observation emits a false edge`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		#expect(sut.noteIdleTimeout() == true)
		#expect(sut.isDetecting == false)
	}

	@Test
	func `idle timeout without prior observation is a no-op`() {
		var sut = DetectionDebouncer()
		#expect(sut.noteIdleTimeout() == false)
		#expect(sut.isDetecting == false)
	}

	@Test
	func `double idle timeout does not re-emit false`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		_ = sut.noteIdleTimeout()
		#expect(sut.noteIdleTimeout() == false)
	}

	@Test
	func `observation after idle timeout re-emits true`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		_ = sut.noteIdleTimeout()
		#expect(sut.noteObservation() == true)
	}

	@Test
	func `reset while detecting emits a trailing false edge`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		#expect(sut.reset() == true)
		#expect(sut.isDetecting == false)
	}

	@Test
	func `reset while not detecting is a no-op`() {
		var sut = DetectionDebouncer()
		#expect(sut.reset() == false)
	}

	@Test
	func `reset after idle timeout does not double-emit`() {
		var sut = DetectionDebouncer()
		_ = sut.noteObservation()
		_ = sut.noteIdleTimeout()
		#expect(sut.reset() == false)
	}
}
