//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Filters `[ScanResult]` against a user-supplied query. Case- and
/// diacritic-insensitive. Matches against a narrow per-type field
/// index — never against payload pieces that would leak privacy
/// (Wi-Fi passwords, email bodies, URL paths).
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
/// | `.contact`  | `rawContent` (full vCard — until structured parsing lands) |
public nonisolated enum HistorySearch {
	/// Empty / whitespace-only query returns `results` unchanged;
	/// relative order is preserved.
	public static func filter(_ results: [ScanResult], query: String) -> [ScanResult] {
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
			// Opaque URLs without an authority (e.g. `data:...`) have
			// `host == nil` and therefore no derived index.
			url.host().map { [$0] } ?? []

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
			// Until vCard parsing lands, index the raw vCard so the
			// user can still find a contact by name / phone / email.
			[result.rawContent]
		}
	}

	private static func formatLocation(latitude: Double, longitude: Double) -> String {
		// Must stay byte-identical to the inspector's coordinate row
		// so typing the visible string into search always matches.
		"\(CoordinateFormatter.format(latitude)), \(CoordinateFormatter.format(longitude))"
	}

	private static func contains(_ needle: String, in haystack: String) -> Bool {
		haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
	}
}
