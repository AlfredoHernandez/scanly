//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

/// `ScanResult` test fixture with overridable fields. `type` defaults
/// to `.text(rawContent)` so the `HistorySearch` per-row index matches
/// `rawContent` verbatim — pass an explicit `type:` for structured
/// payload tests.
public func anyResult(
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

public func timestamp(_ secondsFromEpoch: TimeInterval) -> Date {
	Date(timeIntervalSince1970: secondsFromEpoch)
}

public func anyError() -> NSError {
	NSError(domain: "test.history", code: 0)
}
