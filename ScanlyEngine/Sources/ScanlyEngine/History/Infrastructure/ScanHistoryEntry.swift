//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import SwiftData

/// SwiftData persistence model for a single history row. One row per
/// unique `rawContent`; re-scans update `lastScannedAt` and bump
/// `scanCount` in place. The `QRType` is re-parsed from `rawContent`
/// on read — `typeDiscriminator` is denormalized for analytics, not
/// the parser's input.
@Model
public final class ScanHistoryEntry {
	/// Captured from `ScanResult.id` at insert and never reassigned on
	/// upsert, so a re-scanned row keeps the same SwiftUI identity
	/// across reloads instead of animating as a fresh insertion.
	public var id: UUID

	/// Unique key. No normalization — `HTTP://Example.com` and
	/// `http://example.com` deliberately stay distinct.
	@Attribute(.unique) public var rawContent: String

	/// `QRType.discriminator`. Case name only so the column is safe
	/// to log; the typed value is re-parsed from `rawContent` on read.
	public var typeDiscriminator: String

	/// `BarcodeFormat.rawValue`. Decode via `BarcodeFormat(rawValue:)`
	/// with a `.other` fallback for forward-compatibility.
	public var format: String

	/// Timestamp of the initial insert. Immutable on upsert.
	public var firstScannedAt: Date

	/// Timestamp of the most recent scan. Drives the descending sort
	/// of the history list.
	public var lastScannedAt: Date

	/// Incremented on every upsert. Persisted for future use; not
	/// surfaced yet.
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
