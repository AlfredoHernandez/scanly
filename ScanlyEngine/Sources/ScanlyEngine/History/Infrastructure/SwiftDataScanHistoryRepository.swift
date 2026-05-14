//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import SwiftData

/// Production `ScanHistoryRepository` backed by a SwiftData
/// `ModelContext`. Each mutating call ends with an explicit
/// `context.save()` so a scan either lands in history or doesn't —
/// no partial-commit windows from autosave.
@MainActor
public final class SwiftDataScanHistoryRepository: ScanHistoryRepository {
	private let context: ModelContext
	private let parser: QRContentParsing

	public init(context: ModelContext, parser: QRContentParsing) {
		self.context = context
		self.parser = parser
	}

	public func save(_ result: ScanResult) throws {
		if let existing = try fetchEntry(rawContent: result.rawContent) {
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

	public func all() throws -> [ScanResult] {
		let descriptor = FetchDescriptor<ScanHistoryEntry>(
			sortBy: [SortDescriptor(\.lastScannedAt, order: .reverse)],
		)
		return try context.fetch(descriptor).map(toScanResult)
	}

	public func delete(_ entry: ScanResult) throws {
		guard let row = try fetchEntry(rawContent: entry.rawContent) else { return }
		context.delete(row)
		try context.save()
	}

	public func delete(_ entries: [ScanResult]) throws {
		let keys = Set(entries.map(\.rawContent))
		guard !keys.isEmpty else { return }
		let descriptor = FetchDescriptor<ScanHistoryEntry>(
			predicate: #Predicate { keys.contains($0.rawContent) },
		)
		for row in try context.fetch(descriptor) {
			context.delete(row)
		}
		try context.save()
	}

	public func deleteAll() throws {
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
			format: BarcodeFormat(rawValue: entry.format) ?? .other,
			scannedAt: entry.lastScannedAt,
		)
	}
}
