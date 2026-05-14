//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

/// Array-backed test double for `ScanHistoryRepository`. Honors the
/// upsert contract: saving the same `rawContent` twice produces a
/// single row, and the original `id` is preserved across the update.
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

	public var saveError: Error?
	public var readError: Error?
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
