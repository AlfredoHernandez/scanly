//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Persistence seam for scan history. Conformers store, query, and
/// delete `ScanResult` rows keyed by `rawContent`.
///
/// `@MainActor` because production callers and SwiftData's
/// `ModelContext` both live on the main actor; the dataset is small
/// enough that synchronous methods stay well below a frame budget.
@MainActor
public protocol ScanHistoryRepository: AnyObject {
	/// Upserts `result` keyed by `rawContent`. On upsert the row's
	/// original `id`, `firstScannedAt`, `format`, and
	/// `typeDiscriminator` are preserved so list diffing stays stable;
	/// only `lastScannedAt` and `scanCount` change.
	func save(_ result: ScanResult) throws

	/// Every persisted entry mapped back to `ScanResult`, ordered by
	/// `lastScannedAt` descending.
	func all() throws -> [ScanResult]

	/// No-op when no row matches.
	func delete(_ entry: ScanResult) throws

	/// Entries that don't match any row are ignored.
	func delete(_ entries: [ScanResult]) throws

	func deleteAll() throws
}
