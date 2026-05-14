//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Persistence seam for scan history (§10.2). Conformers store, query,
/// and delete `ScanResult` rows keyed by `rawContent`.
///
/// Production wires this to a SwiftData-backed implementation; tests
/// and previews swap in an in-memory fake so the rest of the codebase
/// never touches `ModelContext` directly.
///
/// `@MainActor` because both production callers (`ScanResultCoordinator`,
/// `HistoryViewModel`) and the SwiftData `ModelContext` itself live on
/// the main actor. Methods are synchronous: v1.0's dataset is bounded
/// to thousands of rows (§10.2.4) and in-memory operations stay well
/// below a frame budget.
@MainActor
protocol ScanHistoryRepository: AnyObject {
	/// Upserts `result` keyed by `rawContent` per §10.2.2. New rows
	/// start with `scanCount = 1` and matching `firstScannedAt` /
	/// `lastScannedAt`. Existing rows set `lastScannedAt` to
	/// `result.scannedAt` and increment `scanCount`; `firstScannedAt`
	/// is immutable after the initial insert. On upsert the row's
	/// original identity (`ScanResult.id`, `firstScannedAt`, `format`,
	/// `typeDiscriminator`) is preserved so list diffing stays stable.
	func save(_ result: ScanResult) throws

	/// Returns every persisted entry mapped back to `ScanResult`,
	/// ordered by `lastScannedAt` descending. The `scannedAt` on each
	/// returned result is the row's `lastScannedAt`; the
	/// `firstScannedAt` / `scanCount` metadata is persisted for future
	/// use but not surfaced in v1.0.
	func all() throws -> [ScanResult]

	/// Removes the entry whose `rawContent` matches `entry.rawContent`.
	/// No-op when no row matches.
	func delete(_ entry: ScanResult) throws

	/// Batch variant of `delete` for the multi-select path in §3.3.
	/// Entries whose `rawContent` does not match any row are ignored.
	func delete(_ entries: [ScanResult]) throws

	/// Clears every entry. Surfaced by §3.3's "Clear history" action.
	func deleteAll() throws

	/// Returns the entries matching `query` against the field
	/// enumeration from §10.2.5, ordered by `lastScannedAt` desc.
	/// An empty / whitespace-only query returns the full list.
	///
	/// The v1.0 contract narrows the field set so that sensitive
	/// payload pieces (Wi-Fi password, email subject/body, SMS body,
	/// URL path / query / fragment) are never matched against — even
	/// though they are visible in the detail view. The detail-view
	/// inspector and the search index are deliberately decoupled.
	func search(query: String) throws -> [ScanResult]
}
