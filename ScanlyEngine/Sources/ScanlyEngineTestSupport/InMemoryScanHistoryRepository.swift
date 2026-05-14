//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

/// Test double for `ScanHistoryRepository` backed by an array. Lets
/// coordinator and view-model tests exercise the persistence seam
/// without standing up a real SwiftData `ModelContainer`.
///
/// The fake honors the upsert contract from §10.2.2 — saving the same
/// `rawContent` twice produces a single row, and the original
/// `ScanResult.id` is preserved across the update so list-view diffing
/// stays stable on reload.
@MainActor
public final class InMemoryScanHistoryRepository: ScanHistoryRepository {
	private struct Row {
		let id: UUID
		let rawContent: String
		let type: QRType
		let format: BarcodeFormat
		let firstScannedAt: Date
		var lastScannedAt: Date
		var scanCount: Int
	}

	private var rows: [Row] = []

	/// When non-nil, the next `save` call throws this error and leaves
	/// the store unchanged. Tests use it to drive the
	/// "save fails → no history entry" branch documented in §10.2.1.
	public var saveError: Error?

	/// When non-nil, the next read (`all`, `search`) throws this error.
	public var readError: Error?

	/// When non-nil, the next delete call (`delete`, `deleteAll`)
	/// throws this error and leaves the store unchanged.
	public var deleteError: Error?

	public init() {}

	public func save(_ result: ScanResult) throws {
		if let saveError { throw saveError }
		if let index = rows.firstIndex(where: { $0.rawContent == result.rawContent }) {
			rows[index].lastScannedAt = result.scannedAt
			rows[index].scanCount += 1
		} else {
			rows.append(Row(
				id: result.id,
				rawContent: result.rawContent,
				type: result.type,
				format: result.format,
				firstScannedAt: result.scannedAt,
				lastScannedAt: result.scannedAt,
				scanCount: 1,
			))
		}
	}

	public func all() throws -> [ScanResult] {
		if let readError { throw readError }
		return rows
			.sorted { $0.lastScannedAt > $1.lastScannedAt }
			.map(Self.toScanResult)
	}

	public func delete(_ entry: ScanResult) throws {
		if let deleteError { throw deleteError }
		rows.removeAll { $0.rawContent == entry.rawContent }
	}

	public func delete(_ entries: [ScanResult]) throws {
		if let deleteError { throw deleteError }
		let keys = Set(entries.map(\.rawContent))
		rows.removeAll { keys.contains($0.rawContent) }
	}

	public func deleteAll() throws {
		if let deleteError { throw deleteError }
		rows.removeAll()
	}

	private static func toScanResult(_ row: Row) -> ScanResult {
		ScanResult(
			id: row.id,
			rawContent: row.rawContent,
			type: row.type,
			format: row.format,
			scannedAt: row.lastScannedAt,
		)
	}
}
