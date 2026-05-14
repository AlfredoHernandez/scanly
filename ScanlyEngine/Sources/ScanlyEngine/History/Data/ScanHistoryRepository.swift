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
public protocol ScanHistoryRepository: AnyObject {
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
}

// Note: search is *not* a protocol requirement. Per §10.2's
// "Implications for current code" the v1.0 search runs in-memory in
// the view model over a `@Query`-loaded snapshot, with the
// field-enumeration semantics living in the pure `HistorySearch`
// type. Keeping a `search(query:)` requirement on the repository
// would mean both the in-memory fake and the SwiftData implementation
// have to maintain a parallel filter that the VM never actually
// calls — two extra surfaces to keep in sync with `HistorySearch`
// for zero production benefit.
