//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
@testable import ScanlyUI
import Foundation
import ScanlyEngineTestSupport
import Testing

@MainActor
struct HistoryViewModelTests {
	// MARK: - load()

	@Test
	func `load is idle in the loading state until called`() {
		let (sut, _) = makeSUT()

		#expect(sut.state == .loading)
		#expect(sut.entries.isEmpty)
	}

	@Test
	func `load populates entries from the repository and transitions to loaded`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		try repository.save(anyResult(rawContent: "b"))

		sut.load()

		#expect(sut.state == .loaded)
		#expect(sut.entries.map(\.rawContent).contains("a"))
		#expect(sut.entries.map(\.rawContent).contains("b"))
	}

	@Test
	func `load on a read failure transitions to failed and clears entries`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "stale"))
		sut.load()
		#expect(sut.entries.count == 1)

		repository.readError = anyError()
		sut.load()

		#expect(isFailed(sut.state), "Expected .failed, got \(sut.state)")
		#expect(sut.entries.isEmpty, "Failed load must drop stale entries; the list mustn't render an inconsistent snapshot")
	}

	@Test
	func `load recovers to loaded after a transient failure`() throws {
		// The `.failed` placeholder shows a Try Again button that
		// calls `load()` again. Without resetting `state` at the top
		// of `load()` the failure would be terminal — verify the
		// happy path back to `.loaded` is wired.
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		repository.readError = anyError()
		sut.load()
		#expect(isFailed(sut.state))

		repository.readError = nil
		sut.load()

		#expect(sut.state == .loaded)
		#expect(sut.entries.map(\.rawContent) == ["a"])
	}

	// MARK: - visibleEntries (search delegation)

	@Test
	func `visibleEntries with empty query is the full snapshot`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		try repository.save(anyResult(rawContent: "b"))
		sut.load()

		#expect(sut.visibleEntries.count == 2)
	}

	@Test
	func `visibleEntries applies the search query via HistorySearch`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "favorite place"))
		try repository.save(anyResult(rawContent: "something else"))
		sut.load()

		sut.searchQuery = "favorite"

		#expect(sut.visibleEntries.map(\.rawContent) == ["favorite place"])
	}

	@Test
	func `visibleEntries honors the URL-host-only search rule (delegates to HistorySearch)`() throws {
		// Smoke test that the VM goes through `HistorySearch`, not a
		// home-grown rawContent search. A search for a URL path
		// substring must be suppressed per §10.2.5; if the VM ever
		// rebuilt the search logic inline it would regress this.
		let (sut, repository) = makeSUT()
		let url = try #require(URL(string: "https://example.com/secret-page"))
		try repository.save(anyResult(rawContent: "https://example.com/secret-page", type: .url(url)))
		sut.load()

		sut.searchQuery = "secret-page"

		#expect(sut.visibleEntries.isEmpty, "URL path is excluded from search per §10.2.5")
	}

	// MARK: - delete(_:)

	@Test
	func `delete removes the matching entry and reloads`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		try repository.save(anyResult(rawContent: "b"))
		sut.load()

		sut.delete(anyResult(rawContent: "a"))

		#expect(sut.entries.map(\.rawContent) == ["b"])
	}

	@Test
	func `delete leaves entries unchanged when the repository throws`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		sut.load()
		repository.deleteError = anyError()

		sut.delete(anyResult(rawContent: "a"))

		#expect(sut.entries.count == 1, "Failed delete must leave the list as it was")
	}

	// MARK: - deleteSelected()

	@Test
	func `deleteSelected with an empty selection is a no-op`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		sut.load()

		sut.deleteSelected()

		#expect(sut.entries.count == 1, "Empty selection must not wipe the list")
	}

	@Test
	func `deleteSelected removes every selected entry`() throws {
		let (sut, repository) = makeSUT()
		let resultA = anyResult(rawContent: "a")
		let resultB = anyResult(rawContent: "b")
		let resultC = anyResult(rawContent: "c")
		try repository.save(resultA)
		try repository.save(resultB)
		try repository.save(resultC)
		sut.load()

		sut.selection = [resultA.id, resultC.id]
		sut.deleteSelected()

		#expect(sut.entries.map(\.rawContent) == ["b"])
		#expect(sut.selection.isEmpty, "Selection must clear after a successful batch delete")
	}

	@Test
	func `deleteSelected keeps the selection when the repository throws`() throws {
		let (sut, repository) = makeSUT()
		let resultA = anyResult(rawContent: "a")
		try repository.save(resultA)
		sut.load()
		repository.deleteError = anyError()

		sut.selection = [resultA.id]
		sut.deleteSelected()

		#expect(sut.entries.count == 1, "Failed batch-delete must leave entries in place")
		#expect(sut.selection == [resultA.id], "Selection state must survive a failed batch delete so the user can retry")
	}

	// MARK: - deleteAll()

	@Test
	func `deleteAll clears every entry and the selection`() throws {
		let (sut, repository) = makeSUT()
		let resultA = anyResult(rawContent: "a")
		let resultB = anyResult(rawContent: "b")
		try repository.save(resultA)
		try repository.save(resultB)
		sut.load()
		sut.selection = [resultA.id]

		sut.deleteAll()

		#expect(sut.entries.isEmpty)
		#expect(sut.selection.isEmpty)
	}

	@Test
	func `deleteAll leaves entries unchanged when the repository throws`() throws {
		let (sut, repository) = makeSUT()
		try repository.save(anyResult(rawContent: "a"))
		sut.load()
		repository.deleteError = anyError()

		sut.deleteAll()

		#expect(sut.entries.count == 1, "Failed clear must not lie about the on-disk state")
	}

	// MARK: - Helpers

	private func makeSUT() -> (HistoryViewModel, InMemoryScanHistoryRepository) {
		let repository = InMemoryScanHistoryRepository()
		let viewModel = HistoryViewModel(repository: repository)
		return (viewModel, repository)
	}

	/// Pattern-match helper for the `.failed` case so tests can read
	/// `#expect(isFailed(sut.state))` instead of unrolling `if case`.
	private func isFailed(_ state: HistoryViewModel.State) -> Bool {
		if case .failed = state { true } else { false }
	}
}
