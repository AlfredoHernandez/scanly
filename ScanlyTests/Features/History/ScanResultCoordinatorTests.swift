//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
@testable import ScanlyUI
import Foundation
import Testing

@MainActor
struct ScanResultCoordinatorTests {
	@Test
	func `latestResult is nil before any present call`() {
		let (sut, _) = makeSUT()
		#expect(sut.latestResult == nil)
	}

	@Test
	func `present publishes the result on latestResult`() {
		let (sut, _) = makeSUT()
		let result = anyResult(rawContent: "https://example.com")

		sut.present(result)

		#expect(sut.latestResult == result, "Present must surface the value to the binding")
	}

	@Test
	func `present persists the result via the repository`() throws {
		let (sut, repository) = makeSUT()
		let result = anyResult(rawContent: "https://example.com")

		sut.present(result)

		#expect(
			try repository.all().map(\.rawContent) == ["https://example.com"],
			"Coordinator is the single persistence call-site — every present must reach the repo",
		)
	}

	@Test
	func `present still publishes when the repository save fails`() {
		// §10.2.1 best-effort save: the sheet is shown for the current
		// scan even if persistence fails. The user-facing flow stays
		// uninterrupted; the history list simply won't carry the row.
		// `present` reaching the `latestResult` write also proves the
		// thrown error was absorbed (a propagated throw would skip the
		// assignment and trip this test).
		let (sut, repository) = makeSUT()
		repository.saveError = anyError()
		let result = anyResult(rawContent: "https://example.com")

		sut.present(result)

		#expect(sut.latestResult == result, "Failed save must not block presentation")
	}

	@Test
	func `present overwrites a previously published result`() {
		let (sut, _) = makeSUT()
		sut.present(anyResult(rawContent: "first"))
		sut.present(anyResult(rawContent: "second"))

		#expect(sut.latestResult?.rawContent == "second")
	}

	@Test
	func `setting latestResult to nil clears the binding without touching the repository`() throws {
		// SwiftUI's `.sheet(item:)` dismisses by writing `nil` to the
		// binding. That path must not trigger a save (or any other
		// repository call) — the persistence side-effect belongs to
		// `present`, not to dismissal.
		let (sut, repository) = makeSUT()
		sut.present(anyResult(rawContent: "https://example.com"))
		let priorCount = try repository.all().count

		sut.latestResult = nil

		#expect(sut.latestResult == nil)
		#expect(try repository.all().count == priorCount, "Dismissal must not re-save the cleared result")
	}

	// MARK: - Helpers

	private func makeSUT() -> (ScanResultCoordinator, InMemoryScanHistoryRepository) {
		let repository = InMemoryScanHistoryRepository()
		let coordinator = ScanResultCoordinator(repository: repository)
		return (coordinator, repository)
	}
}
