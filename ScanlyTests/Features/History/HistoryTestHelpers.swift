//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation

// Shared builders for the §10.2 history test suites. Both the
// `InMemoryScanHistoryRepository` unit tests and the SwiftData
// integration tests build `ScanResult` fixtures and named timestamps
// the same way; centralizing them here keeps a future change to
// `ScanResult`'s initializer (or its defaults) a single-file edit.

/// Builds a `ScanResult` with sensible defaults for tests that don't
/// care about the exact field values. Every parameter is overridable
/// so individual tests can pin the dimension they're exercising
/// (`rawContent` for upsert tests, `id` for identity-preservation
/// tests, `at` for ordering tests, etc.).
///
/// `type` defaults to `.text(rawContent)` so the per-row index built
/// by `HistorySearch` (§10.2.5) matches `rawContent` verbatim — that
/// is the implicit assumption of older "search by rawContent
/// substring" tests, which would otherwise break when `rawContent`
/// happened to look like a URL but type was hardcoded to a different
/// URL. Pass an explicit `type:` for tests that need a structured
/// QR payload.
func anyResult(
	id: UUID = UUID(),
	rawContent: String = "https://example.com",
	type: QRType? = nil,
	format: BarcodeFormat = .qr,
	at scannedAt: Date = Date(timeIntervalSince1970: 0),
) -> ScanResult {
	ScanResult(
		id: id,
		rawContent: rawContent,
		type: type ?? .text(rawContent),
		format: format,
		scannedAt: scannedAt,
	)
}

/// `Date` offset from the Unix epoch by `secondsFromEpoch`. Cheaper
/// to read than a `Date(timeIntervalSince1970:)` literal at every
/// call site and keeps relative ordering obvious.
func timestamp(_ secondsFromEpoch: TimeInterval) -> Date {
	Date(timeIntervalSince1970: secondsFromEpoch)
}

/// An `NSError` with a stable test-only domain. Tests inject it
/// into the `InMemoryScanHistoryRepository.{saveError,readError,
/// deleteError}` slots to drive the throwing branches.
func anyError() -> NSError {
	NSError(domain: "test.history", code: 0)
}
