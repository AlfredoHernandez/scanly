//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import SwiftData
import Testing

/// Integration tests for `SwiftDataScanHistoryRepository` against an
/// in-memory `ModelContainer`. Mirrors the contract suite in
/// `InMemoryScanHistoryRepositoryTests` plus a few SwiftData-specific
/// invariants: persistence across context recreations and round-trip
/// fidelity through the entry ↔ `ScanResult` mapping.
@MainActor
struct SwiftDataScanHistoryRepositoryTests {
	// MARK: - Contract parity with InMemory fake

	@Test
	func `all returns empty when nothing has been saved`() throws {
		let (sut, _) = try makeSUT()
		#expect(try sut.all().isEmpty)
	}

	@Test
	func `all returns entries ordered by most recent scan first`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "first", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "second", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "third", at: timestamp(120)))

		#expect(try sut.all().map(\.rawContent) == ["third", "second", "first"])
	}

	@Test
	func `save appends a new row that all returns`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com"))

		let entries = try sut.all()
		#expect(entries.count == 1)
		#expect(entries[0].rawContent == "https://example.com")
	}

	@Test
	func `save preserves the source id across the entry round-trip`() throws {
		let (sut, _) = try makeSUT()
		let id = UUID()

		try sut.save(anyResult(id: id, rawContent: "https://example.com"))

		#expect(try sut.all()[0].id == id)
	}

	@Test
	func `save with existing rawContent collapses to a single row`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(60)))

		#expect(try sut.all().count == 1)
	}

	@Test
	func `save with existing rawContent updates lastScannedAt to the new timestamp`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(60)))

		#expect(try sut.all()[0].scannedAt == timestamp(60))
	}

	@Test
	func `save with existing rawContent preserves the original id`() throws {
		let (sut, _) = try makeSUT()
		let originalID = UUID()
		try sut.save(anyResult(id: originalID, rawContent: "https://example.com"))
		try sut.save(anyResult(id: UUID(), rawContent: "https://example.com"))

		#expect(try sut.all()[0].id == originalID)
	}

	@Test
	func `save with existing rawContent moves the row to the top of the list`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "b", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "a", at: timestamp(120)))

		#expect(try sut.all().map(\.rawContent) == ["a", "b"])
	}

	@Test
	func `save with existing rawContent preserves the original format and parsed type`() throws {
		let (sut, _) = try makeSUT()
		let initialURL = try #require(URL(string: "https://example.com"))
		try sut.save(anyResult(rawContent: "https://example.com", type: .url(initialURL), format: .qr))
		// Re-save with a deliberately wrong type/format — the row's
		// schema-frozen values must win on the next read.
		try sut.save(anyResult(rawContent: "https://example.com", type: .text("https://example.com"), format: .code128))

		let entry = try sut.all()[0]
		#expect(entry.format == .qr)
		#expect(entry.type == .url(initialURL))
	}

	@Test
	func `delete single removes the matching row`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.delete(anyResult(rawContent: "a"))

		#expect(try sut.all().map(\.rawContent) == ["b"])
	}

	@Test
	func `delete single is a no-op when no row matches`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a"))

		try sut.delete(anyResult(rawContent: "nonexistent"))

		#expect(try sut.all().count == 1)
	}

	@Test
	func `delete batch removes every matching row`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "b", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "c", at: timestamp(120)))

		try sut.delete([anyResult(rawContent: "a"), anyResult(rawContent: "c")])

		#expect(try sut.all().map(\.rawContent) == ["b"])
	}

	@Test
	func `delete batch ignores entries that do not match any row`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.delete([anyResult(rawContent: "nonexistent")])

		#expect(try sut.all().count == 2)
	}

	@Test
	func `delete batch with empty input is a no-op`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a"))

		try sut.delete([])

		#expect(try sut.all().count == 1)
	}

	@Test
	func `deleteAll clears every row`() throws {
		let (sut, _) = try makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.deleteAll()

		#expect(try sut.all().isEmpty)
	}

	// MARK: - SwiftData-specific invariants

	@Test
	func `entries survive a fresh repository constructed against the same container`() throws {
		// Mirrors a hot-launch / cold-restart: the same model container
		// stays alive (the production composition root holds it for
		// the app lifetime) but a fresh repository instance reads
		// what the previous one wrote.
		let (firstRepo, container) = try makeSUT()
		try firstRepo.save(anyResult(rawContent: "https://example.com", at: timestamp(0)))
		try firstRepo.save(anyResult(rawContent: "https://other.com", at: timestamp(60)))

		let secondRepo = SwiftDataScanHistoryRepository(context: ModelContext(container))

		#expect(try secondRepo.all().map(\.rawContent) == ["https://other.com", "https://example.com"])
	}

	@Test
	func `read round-trips the parsed type via the injected parser`() throws {
		// `QRType` is not stored directly — the repository re-parses
		// `rawContent` on every read. Inject a stub parser so the
		// test can prove the seam without coupling to the real
		// QR-content rules (those have their own suite).
		let stubParser = try StubContentParser(verdict: .url(#require(URL(string: "https://stub"))))
		let (_, container) = try makeSUT()
		let sut = SwiftDataScanHistoryRepository(context: ModelContext(container), parser: stubParser)
		try sut.save(anyResult(rawContent: "https://example.com"))

		let entry = try sut.all()[0]
		#expect(try entry.type == .url(#require(URL(string: "https://stub"))))
	}

	@Test
	func `read decodes a stored format string back to its BarcodeFormat case`() throws {
		let (sut, _) = try makeSUT()

		try sut.save(anyResult(rawContent: "1234567890128", format: .ean13))

		#expect(try sut.all()[0].format == .ean13)
	}

	// MARK: - Helpers

	private func makeSUT() throws -> (SwiftDataScanHistoryRepository, ModelContainer) {
		let schema = Schema([ScanHistoryEntry.self])
		let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try ModelContainer(for: schema, configurations: [configuration])
		let repository = SwiftDataScanHistoryRepository(context: ModelContext(container))
		return (repository, container)
	}
}

/// Returns a fixed verdict regardless of input. Lets the repository
/// tests prove the parser seam is exercised on read without coupling
/// to the real QR content rules.
private struct StubContentParser: QRContentParsing {
	let verdict: QRType
	func parse(_: String) -> QRType {
		verdict
	}
}
