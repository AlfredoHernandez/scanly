//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated extension QRType {
	/// Structured breakdown shown inside the result sheet's inspector.
	/// Returns an empty array for scans whose only signal is the raw
	/// content itself (bare text), so the view can hide the inspector
	/// entirely rather than show a redundant "Text: ..." row.
	var inspectorRows: [InspectorRow] {
		switch self {
		case let .url(url):
			urlRows(from: url)

		case let .wifi(credentials):
			wifiRows(from: credentials)

		case let .email(payload):
			emailRows(from: payload)

		case let .sms(payload):
			smsRows(from: payload)

		case let .phone(number):
			[.localized("scanner.result.phone.number", value: number)]

		case let .location(latitude, longitude):
			[
				.localized("scanner.result.location.latitude", value: Self.formatCoordinate(latitude)),
				.localized("scanner.result.location.longitude", value: Self.formatCoordinate(longitude)),
			]

		case .contact, .text:
			// vCard parsing is out of scope for the inspector and plain
			// text has no structure beyond the content section.
			[]
		}
	}

	private func urlRows(from url: URL) -> [InspectorRow] {
		let breakdown = URLBreakdown(url: url)
		var rows: [InspectorRow] = []
		if let scheme = breakdown.scheme {
			rows.append(.localized("scanner.result.url.scheme", value: scheme))
		}
		if let host = breakdown.host {
			rows.append(.localized("scanner.result.url.host", value: host))
		}
		if let port = breakdown.port {
			rows.append(.localized("scanner.result.url.port", value: String(port)))
		}
		if let path = breakdown.path {
			rows.append(.localized("scanner.result.url.path", value: path))
		}
		for item in breakdown.queryItems {
			rows.append(.verbatim(item.name, value: item.value ?? ""))
		}
		if let fragment = breakdown.fragment {
			rows.append(.localized("scanner.result.url.fragment", value: fragment))
		}
		return rows
	}

	private func wifiRows(from credentials: WiFiCredentials) -> [InspectorRow] {
		var rows: [InspectorRow] = [
			.localized("scanner.result.wifi.ssid", value: credentials.ssid),
		]
		if let password = credentials.password {
			rows.append(.localized("scanner.result.wifi.password", value: password))
		}
		rows.append(.localized("scanner.result.wifi.security", value: credentials.security.displayName))
		if credentials.isHidden {
			rows.append(.localized(
				"scanner.result.wifi.hidden",
				value: String(localized: "scanner.result.wifi.hidden.yes"),
			))
		}
		return rows
	}

	private func emailRows(from payload: EmailPayload) -> [InspectorRow] {
		var rows: [InspectorRow] = [
			.localized("scanner.result.email.address", value: payload.address),
		]
		if let subject = payload.subject, !subject.isEmpty {
			rows.append(.localized("scanner.result.email.subject", value: subject))
		}
		if let body = payload.body, !body.isEmpty {
			rows.append(.localized("scanner.result.email.body", value: body))
		}
		return rows
	}

	private func smsRows(from payload: SMSPayload) -> [InspectorRow] {
		var rows: [InspectorRow] = [
			.localized("scanner.result.sms.number", value: payload.number),
		]
		if let body = payload.body, !body.isEmpty {
			rows.append(.localized("scanner.result.sms.body", value: body))
		}
		return rows
	}

	private static func formatCoordinate(_ value: Double) -> String {
		value.formatted(.number.precision(.fractionLength(0 ... 6)))
	}
}

nonisolated extension WiFiSecurity {
	/// Standard names (WPA/WEP) stay untranslated; only "none" is surfaced
	/// as a localized "Open network" label.
	var displayName: String {
		switch self {
		case .wpa: "WPA/WPA2/WPA3"

		case .wep: "WEP"

		case .none: String(localized: "scanner.result.wifi.security.none")
		}
	}
}
