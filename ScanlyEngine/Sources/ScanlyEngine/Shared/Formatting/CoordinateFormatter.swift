//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Locale-invariant coordinate formatter. Pinned to `en_US_POSIX` so
/// the displayed value matches `geo:` rawContent and the search index
/// byte-for-byte regardless of the device's decimal separator. Up to
/// six fraction digits (~11 cm at the equator).
public nonisolated enum CoordinateFormatter {
	public static func format(_ value: Double) -> String {
		value.formatted(
			.number
				.locale(Locale(identifier: "en_US_POSIX"))
				.precision(.fractionLength(0 ... 6)),
		)
	}
}
