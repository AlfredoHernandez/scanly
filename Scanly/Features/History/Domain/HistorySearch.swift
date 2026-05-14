//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Pure search algorithm for the history feature per §10.2.5.
///
/// Filters `[ScanResult]` against a user-supplied query, matching only
/// against the **explicit field enumeration** the spec pins. The match
/// is case- and diacritic-insensitive.
///
/// **Indexed fields per type**
///
/// | Type        | Indexed strings                              |
/// |-------------|----------------------------------------------|
/// | `.url`      | URL host (only — no path, query, fragment)   |
/// | `.wifi`     | SSID (only — never the password)             |
/// | `.email`    | Address (never subject or body)              |
/// | `.sms`      | Number (never the body)                      |
/// | `.phone`    | Number                                       |
/// | `.location` | Formatted "latitude, longitude"              |
/// | `.text`     | `rawContent`                                 |
/// | `.contact`  | `rawContent` (full vCard — v1.0 caveat)      |
///
/// The exclusion is deliberate: payload pieces like Wi-Fi passwords,
/// email bodies, and URL paths are visible in the detail-view
/// inspector but must never surface a history row from a search
/// match against them (§10.2.5). For structured types (`.url`,
/// `.wifi`, `.email`, `.sms`) this means `rawContent` is **not**
/// matched verbatim — substring matches go through the redacted
/// per-field index above. `.text` and `.contact` index `rawContent`
/// because v1.0 has no further breakdown for those payloads.
nonisolated enum HistorySearch {
	/// Returns the subset of `results` matching `query` against the
	/// §10.2.5 field enumeration. An empty / whitespace-only query
	/// returns `results` unchanged; the relative order of survivors
	/// is preserved (callers sort upstream, typically by
	/// `lastScannedAt` descending).
	static func filter(_ results: [ScanResult], query: String) -> [ScanResult] {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return results }
		return results.filter { matches(trimmed, in: $0) }
	}

	private static func matches(_ query: String, in result: ScanResult) -> Bool {
		indexedStrings(for: result).contains { contains(query, in: $0) }
	}

	private static func indexedStrings(for result: ScanResult) -> [String] {
		switch result.type {
		case let .url(url):
			// `url.host()` returns the decoded host — what the user
			// would type into search. Opaque URLs without an
			// authority (e.g. `data:...`) have `host == nil` and
			// therefore no derived index.
			[url.host()].compactMap(\.self)

		case let .wifi(credentials):
			[credentials.ssid]

		case let .email(payload):
			[payload.address]

		case let .sms(payload):
			[payload.number]

		case let .phone(number):
			[number]

		case let .location(latitude, longitude):
			[formatLocation(latitude: latitude, longitude: longitude)]

		case .text:
			[result.rawContent]

		case .contact:
			// v1.0 ships without structured vCard parsing, so the
			// safest path that still lets the user find a contact by
			// name / phone / email is to index the rawContent vCard
			// verbatim. A future iteration that adds vCard
			// breakdown should narrow this to FN / EMAIL / TEL.
			[result.rawContent]
		}
	}

	private static func formatLocation(latitude: Double, longitude: Double) -> String {
		// Variable precision up to 6 fraction digits — matches the
		// inspector's coordinate formatter so what the user reads on
		// the detail row is also what they type into search.
		let lat = latitude.formatted(.number.precision(.fractionLength(0 ... 6)))
		let lng = longitude.formatted(.number.precision(.fractionLength(0 ... 6)))
		return "\(lat), \(lng)"
	}

	private static func contains(_ needle: String, in haystack: String) -> Bool {
		haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
	}
}
