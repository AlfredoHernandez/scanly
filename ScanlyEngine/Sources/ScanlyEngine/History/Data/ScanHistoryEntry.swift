//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import SwiftData

/// SwiftData persistence model for a single history row (§10.2).
///
/// One row per unique `rawContent`. Re-scanning an existing payload
/// updates `lastScannedAt` and increments `scanCount` in place — the
/// other fields are immutable after the initial insert. The actual
/// `QRType` is re-parsed from `rawContent` on read (the parser is
/// deterministic on rawContent); `typeDiscriminator` is denormalized
/// for future analytics / filtering but is not the parser's input.
@Model
public final class ScanHistoryEntry {
	/// Stable identity captured from `ScanResult.id` at insert and
	/// never reassigned on upsert. List views key SwiftUI diffing on
	/// this so a re-scanned row keeps the same identity across
	/// reloads — without it every reload would animate every row as
	/// a brand-new insertion.
	public var id: UUID

	/// The literal scanned string. Unique across the store: re-scans
	/// upsert the existing row instead of inserting a duplicate
	/// (§10.2.2). No normalization is applied — `HTTP://Example.com`
	/// and `http://example.com` deliberately produce two distinct
	/// rows per the spec's explicit-key tradeoff.
	@Attribute(.unique) public var rawContent: String

	/// `QRType.discriminator` — the case name only, never the
	/// associated values, so the column is safe to surface in
	/// analytics / OSLog. The actual typed value is re-parsed from
	/// `rawContent` on read; this field exists for future filtering
	/// without paying the parser cost per row.
	public var typeDiscriminator: String

	/// `BarcodeFormat.rawValue`. Stored for display only — the
	/// parser does **not** consume `format` to dispatch
	/// (§10.2.2). On read, decode via `BarcodeFormat(rawValue:)`
	/// with a `.other` fallback for forward-compatibility.
	public var format: String

	/// Timestamp of the first insert. Immutable after the initial
	/// save (§10.2.2).
	public var firstScannedAt: Date

	/// Timestamp of the most recent scan. Updated on every upsert.
	/// Drives the descending sort of the history list (§10.2.6).
	public var lastScannedAt: Date

	/// Total number of times this `rawContent` has been scanned.
	/// Starts at 1, incremented on every upsert. Persisted for
	/// future use; not surfaced in v1.0.
	public var scanCount: Int

	public init(
		id: UUID,
		rawContent: String,
		typeDiscriminator: String,
		format: String,
		firstScannedAt: Date,
		lastScannedAt: Date,
		scanCount: Int,
	) {
		self.id = id
		self.rawContent = rawContent
		self.typeDiscriminator = typeDiscriminator
		self.format = format
		self.firstScannedAt = firstScannedAt
		self.lastScannedAt = lastScannedAt
		self.scanCount = scanCount
	}
}
