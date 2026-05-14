//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Shared formatter for geographic coordinates used by both the
/// scanner inspector (§3.4 — Open Maps row) and the history search
/// index (§10.2.5). Pinned to `en_US_POSIX` so the produced string is
/// **locale-invariant** — `37.7749` is rendered with a dot regardless
/// of the device's preferred decimal separator.
///
/// Why locale-invariant: when a user on a French/German locale scans
/// a geo QR, the rawContent is `geo:37.7749,-122.4194` (dot-decimal,
/// per the URI scheme). The inspector showing `37,7749` and the
/// search index showing `37.7749` would diverge — typing `37.77` in
/// the search bar would not match what the user sees on the row.
/// Standardising on dot-decimal everywhere keeps the displayed value
/// and the indexed value byte-identical, which is what every
/// downstream component (search, copy-to-clipboard, deep-link
/// generation) implicitly assumes.
///
/// Precision is up to six fraction digits — roughly 11 cm at the
/// equator, more than enough for any QR-encoded location and matching
/// the convention used by OpenStreetMap / Apple Maps share sheets.
nonisolated enum CoordinateFormatter {
	/// Formats a single coordinate component (latitude or longitude)
	/// to a dot-decimal string with up to six fraction digits.
	static func format(_ value: Double) -> String {
		value.formatted(
			.number
				.locale(Locale(identifier: "en_US_POSIX"))
				.precision(.fractionLength(0 ... 6)),
		)
	}
}
