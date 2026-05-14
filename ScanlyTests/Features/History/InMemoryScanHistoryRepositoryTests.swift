//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

@MainActor
struct InMemoryScanHistoryRepositoryTests {
	// MARK: - all()

	@Test
	func `all returns empty when nothing has been saved`() throws {
		let sut = makeSUT()
		#expect(try sut.all().isEmpty)
	}

	@Test
	func `all returns entries ordered by most recent scan first`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "first", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "second", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "third", at: timestamp(120)))

		let entries = try sut.all()

		#expect(entries.map(\.rawContent) == ["third", "second", "first"])
	}

	// MARK: - save() — insert path

	@Test
	func `save appends a new row that all returns`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com"))

		let entries = try sut.all()

		#expect(entries.count == 1)
		#expect(entries[0].rawContent == "https://example.com")
	}

	@Test
	func `save preserves the source id so list diffing stays stable across reloads`() throws {
		let sut = makeSUT()
		let id = UUID()

		try sut.save(anyResult(id: id, rawContent: "https://example.com"))

		#expect(try sut.all()[0].id == id)
	}

	@Test
	func `save preserves the source format and parsed type`() throws {
		let sut = makeSUT()

		try sut.save(anyResult(rawContent: "1234567890128", type: .text("1234567890128"), format: .ean13))

		let entry = try sut.all()[0]
		#expect(entry.format == .ean13)
		#expect(entry.type == .text("1234567890128"))
	}

	// MARK: - save() — upsert path (§10.2.2)

	@Test
	func `save with existing rawContent collapses to a single row`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(60)))

		#expect(try sut.all().count == 1, "Same rawContent must collapse to a single row per §10.2.2")
	}

	@Test
	func `save with existing rawContent updates lastScannedAt to the new timestamp`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "https://example.com", at: timestamp(60)))

		#expect(try sut.all()[0].scannedAt == timestamp(60))
	}

	@Test
	func `save with existing rawContent preserves the original id`() throws {
		// The id is the canonical identity of the row; a re-scan must
		// not reassign it, or the list view would treat every re-scan
		// as a brand-new item and animate accordingly.
		let sut = makeSUT()
		let originalID = UUID()
		try sut.save(anyResult(id: originalID, rawContent: "https://example.com"))
		try sut.save(anyResult(id: UUID(), rawContent: "https://example.com"))

		#expect(try sut.all()[0].id == originalID)
	}

	@Test
	func `save with existing rawContent moves the row to the top of the list`() throws {
		// §10.2.6: re-scanning an existing entry moves it to the top.
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "b", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "a", at: timestamp(120)))

		#expect(try sut.all().map(\.rawContent) == ["a", "b"])
	}

	@Test
	func `save with existing rawContent preserves the original type and format`() throws {
		// The schema fields `typeDiscriminator` and `format` are
		// captured at the *initial* insert and never overwritten by a
		// subsequent re-scan. In practice the same `rawContent` parses
		// to the same `QRType` (the parser is deterministic on
		// rawContent), but the invariant must hold even if a future
		// caller hands the repo a different type/format on re-save.
		let sut = makeSUT()
		let initialURL = try #require(URL(string: "https://example.com"))
		try sut.save(anyResult(rawContent: "https://example.com", type: .url(initialURL), format: .qr))
		try sut.save(anyResult(rawContent: "https://example.com", type: .text("https://example.com"), format: .code128))

		let entry = try sut.all()[0]
		#expect(entry.format == .qr, "Re-save must not overwrite the original format")
		#expect(entry.type == .url(initialURL), "Re-save must not overwrite the original parsed type")
	}

	// MARK: - save() — error path

	@Test
	func `save propagates the configured error and leaves the store unchanged`() throws {
		let sut = makeSUT()
		sut.saveError = anyError()

		#expect(throws: NSError.self) {
			try sut.save(anyResult())
		}
		#expect(try sut.all().isEmpty, "Failed save must not mutate the store — §10.2.1 best-effort contract")
	}

	// MARK: - delete()

	@Test
	func `delete single removes the matching row`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.delete(anyResult(rawContent: "a"))

		#expect(try sut.all().map(\.rawContent) == ["b"])
	}

	@Test
	func `delete single is a no-op when no row matches`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))

		try sut.delete(anyResult(rawContent: "nonexistent"))

		#expect(try sut.all().count == 1)
	}

	@Test
	func `delete batch removes every matching row`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a", at: timestamp(0)))
		try sut.save(anyResult(rawContent: "b", at: timestamp(60)))
		try sut.save(anyResult(rawContent: "c", at: timestamp(120)))

		try sut.delete([anyResult(rawContent: "a"), anyResult(rawContent: "c")])

		#expect(try sut.all().map(\.rawContent) == ["b"])
	}

	@Test
	func `delete batch ignores entries that do not match any row`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.delete([anyResult(rawContent: "nonexistent")])

		#expect(try sut.all().count == 2)
	}

	@Test
	func `deleteAll clears every row`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))

		try sut.deleteAll()

		#expect(try sut.all().isEmpty)
	}

	// MARK: - error propagation

	@Test
	func `all propagates the configured read error`() {
		let sut = makeSUT()
		sut.readError = anyError()

		#expect(throws: NSError.self) {
			try sut.all()
		}
	}

	@Test
	func `delete propagates the configured delete error and leaves the store unchanged`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		sut.deleteError = anyError()

		#expect(throws: NSError.self) {
			try sut.delete(anyResult(rawContent: "a"))
		}
		#expect(try sut.all().count == 1)
	}

	@Test
	func `delete batch propagates the configured delete error and leaves the store unchanged`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))
		sut.deleteError = anyError()

		#expect(throws: NSError.self) {
			try sut.delete([anyResult(rawContent: "a"), anyResult(rawContent: "b")])
		}
		#expect(try sut.all().count == 2, "Failed batch delete must be atomic — leave every row in place")
	}

	@Test
	func `deleteAll propagates the configured delete error and leaves the store unchanged`() throws {
		let sut = makeSUT()
		try sut.save(anyResult(rawContent: "a"))
		try sut.save(anyResult(rawContent: "b"))
		sut.deleteError = anyError()

		#expect(throws: NSError.self) {
			try sut.deleteAll()
		}
		#expect(try sut.all().count == 2, "Failed clear must leave every row in place")
	}

	// MARK: - Helpers

	private func makeSUT() -> InMemoryScanHistoryRepository {
		InMemoryScanHistoryRepository()
	}
}
