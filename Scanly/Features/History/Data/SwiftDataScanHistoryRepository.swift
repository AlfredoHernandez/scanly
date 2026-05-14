//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import SwiftData

/// Production `ScanHistoryRepository` backed by a SwiftData
/// `ModelContext`. The context is injected so the app composition
/// root passes the production container while tests stand up an
/// in-memory `ModelContainer` per test for isolation.
///
/// Each mutating call ends with an explicit `context.save()`: v1.0's
/// dataset is bounded (§10.2.4) so the per-call write cost stays
/// negligible, and a per-call commit makes the "best-effort save"
/// failure semantics of §10.2.1 observable at the right granularity
/// (each scan either lands in history or doesn't, with no partial-
/// commit windows from autosave).
@MainActor
final class SwiftDataScanHistoryRepository: ScanHistoryRepository {
	private let context: ModelContext
	private let parser: QRContentParsing

	init(context: ModelContext, parser: QRContentParsing = QRContentParser()) {
		self.context = context
		self.parser = parser
	}

	func save(_ result: ScanResult) throws {
		if let existing = try fetchEntry(rawContent: result.rawContent) {
			// Upsert path (§10.2.2): only the activity counters move.
			// `id`, `firstScannedAt`, `typeDiscriminator`, `format`
			// stay frozen at their initial-insert values.
			existing.lastScannedAt = result.scannedAt
			existing.scanCount += 1
		} else {
			context.insert(ScanHistoryEntry(
				id: result.id,
				rawContent: result.rawContent,
				typeDiscriminator: result.type.discriminator,
				format: result.format.rawValue,
				firstScannedAt: result.scannedAt,
				lastScannedAt: result.scannedAt,
				scanCount: 1,
			))
		}
		try context.save()
	}

	func all() throws -> [ScanResult] {
		let descriptor = FetchDescriptor<ScanHistoryEntry>(
			sortBy: [SortDescriptor(\.lastScannedAt, order: .reverse)],
		)
		return try context.fetch(descriptor).map(toScanResult)
	}

	func delete(_ entry: ScanResult) throws {
		guard let row = try fetchEntry(rawContent: entry.rawContent) else { return }
		context.delete(row)
		try context.save()
	}

	func delete(_ entries: [ScanResult]) throws {
		let keys = Set(entries.map(\.rawContent))
		guard !keys.isEmpty else { return }
		// Fetching every row and filtering in memory is correct for
		// the v1.0 bounded dataset. A `#Predicate` over a captured
		// `Set<String>` would push the filter into SwiftData, but
		// the marginal gain isn't worth the macro constraints at
		// this scale.
		let rows = try context.fetch(FetchDescriptor<ScanHistoryEntry>())
		for row in rows where keys.contains(row.rawContent) {
			context.delete(row)
		}
		try context.save()
	}

	func deleteAll() throws {
		try context.delete(model: ScanHistoryEntry.self)
		try context.save()
	}

	// MARK: - Mapping

	private func fetchEntry(rawContent: String) throws -> ScanHistoryEntry? {
		let descriptor = FetchDescriptor<ScanHistoryEntry>(
			predicate: #Predicate { $0.rawContent == rawContent },
		)
		return try context.fetch(descriptor).first
	}

	private func toScanResult(_ entry: ScanHistoryEntry) -> ScanResult {
		ScanResult(
			id: entry.id,
			rawContent: entry.rawContent,
			type: parser.parse(entry.rawContent),
			// `.other` covers the forward-compat case where a stored
			// `format` String predates a `BarcodeFormat` case the
			// running build no longer knows about.
			format: BarcodeFormat(rawValue: entry.format) ?? .other,
			scannedAt: entry.lastScannedAt,
		)
	}
}
