//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import Testing

struct PostDismissCooldownTests {
	@Test
	func `initial state suppresses nothing`() {
		let (sut, _) = makeSUT()
		#expect(sut.shouldSuppress("https://example.com") == false)
	}

	@Test
	func `same content within the window is suppressed`() {
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 1.0)
		#expect(sut.shouldSuppress("https://example.com") == true)
	}

	@Test
	func `same content exactly at the window boundary is not suppressed`() {
		// The window is half-open: [dismissAt, dismissAt + window).
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 2.0)
		#expect(sut.shouldSuppress("https://example.com") == false)
	}

	@Test
	func `different content within the window is not suppressed`() {
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 0.5)
		#expect(sut.shouldSuppress("https://other.com") == false)
	}

	@Test
	func `same content after the window expires is not suppressed`() {
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 2.5)
		#expect(sut.shouldSuppress("https://example.com") == false)
	}

	@Test
	func `recording a new dismissal replaces the prior content`() {
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 0.5)
		sut.recordDismissal(of: "https://other.com")

		clock.advance(by: 0.5)
		#expect(sut.shouldSuppress("https://example.com") == false, "Original content is no longer the just-dismissed one")
		#expect(sut.shouldSuppress("https://other.com") == true, "New content is within its own window")
	}

	@Test
	func `case-sensitive content matching`() {
		var (sut, clock) = makeSUT()
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 0.5)
		#expect(sut.shouldSuppress("HTTPS://EXAMPLE.COM") == false, "Cooldown is keyed by exact rawContent per §10.1.3 — no normalization")
	}

	@Test
	func `custom window is honored`() {
		let clock = TestClock()
		var sut = PostDismissCooldown(window: 0.5, clock: clock.now)
		sut.recordDismissal(of: "https://example.com")

		clock.advance(by: 0.4)
		#expect(sut.shouldSuppress("https://example.com") == true)

		clock.advance(by: 0.2)
		#expect(sut.shouldSuppress("https://example.com") == false)
	}

	// MARK: - Helpers

	private func makeSUT(window: TimeInterval = 2.0) -> (sut: PostDismissCooldown, clock: TestClock) {
		let clock = TestClock()
		let sut = PostDismissCooldown(window: window, clock: clock.now)
		return (sut, clock)
	}
}
