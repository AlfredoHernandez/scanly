//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated protocol QRContentParsing: Sendable {
	func parse(_ content: String) -> QRType
}

nonisolated struct QRContentParser: QRContentParsing {
	private enum LowercasedPrefix {
		static let wifi = "wifi:"
		static let vcard = "begin:vcard"
		static let tel = "tel:"
		static let smsto = "smsto:"
		static let sms = "sms:"
		static let mailto = "mailto:"
		static let geo = "geo:"
		static let http = "http://"
		static let https = "https://"
	}

	func parse(_ content: String) -> QRType {
		let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
		let lower = trimmed.lowercased()

		if lower.hasPrefix(LowercasedPrefix.wifi),
		   let wifi = Self.parseWiFi(body: String(trimmed.dropFirst(LowercasedPrefix.wifi.count)))
		{
			return .wifi(wifi)
		}
		if lower.hasPrefix(LowercasedPrefix.vcard) {
			return .contact(vCard: trimmed)
		}
		if lower.hasPrefix(LowercasedPrefix.tel) {
			let number = trimmed.dropFirst(LowercasedPrefix.tel.count)
				.trimmingCharacters(in: .whitespaces)
			return .phone(number)
		}
		if lower.hasPrefix(LowercasedPrefix.smsto),
		   let sms = Self.parseSMS(body: String(trimmed.dropFirst(LowercasedPrefix.smsto.count)))
		{
			return .sms(sms)
		}
		if lower.hasPrefix(LowercasedPrefix.sms),
		   let sms = Self.parseSMS(body: String(trimmed.dropFirst(LowercasedPrefix.sms.count)))
		{
			return .sms(sms)
		}
		if lower.hasPrefix(LowercasedPrefix.mailto),
		   let email = Self.parseMailto(trimmed)
		{
			return .email(email)
		}
		if lower.hasPrefix(LowercasedPrefix.geo),
		   let location = Self.parseGeo(body: String(trimmed.dropFirst(LowercasedPrefix.geo.count)))
		{
			return .location(latitude: location.latitude, longitude: location.longitude)
		}
		// Only `http(s)://` routes to `.url`; other schemes fall through to `.text`.
		if lower.hasPrefix(LowercasedPrefix.http) || lower.hasPrefix(LowercasedPrefix.https),
		   let url = URL(string: trimmed)
		{
			return .url(url)
		}
		return .text(trimmed)
	}

	/// Parses `WIFI:T:<auth>;S:<ssid>;P:<password>;H:<true|false>;;`. Fields are order-independent.
	private static func parseWiFi(body: String) -> WiFiCredentials? {
		let fields = splitUnescaped(body, separator: ";")

		var type: String?
		var ssid: String?
		var password: String?
		var hidden = false

		for field in fields where !field.isEmpty {
			guard let colonIndex = field.firstIndex(of: ":") else { continue }
			let key = String(field[..<colonIndex]).uppercased()
			let value = String(field[field.index(after: colonIndex)...])
			switch key {
			case "T": type = value

			case "S": ssid = value

			case "P": password = value.isEmpty ? nil : value

			case "H": hidden = (value.lowercased() == "true")

			default: break
			}
		}

		guard let ssid, !ssid.isEmpty else { return nil }

		let security: WiFiSecurity = switch (type ?? "").uppercased() {
		case "WPA", "WPA2", "WPA3": .wpa

		case "WEP": .wep

		default: .none
		}

		return WiFiCredentials(
			ssid: ssid,
			password: security == .none ? nil : password,
			security: security,
			isHidden: hidden,
		)
	}

	/// Splits on `separator` honoring backslash escapes; a trailing unpaired `\` is preserved.
	private static func splitUnescaped(_ input: String, separator: Character) -> [String] {
		var parts: [String] = []
		var current = ""
		var escaped = false
		for ch in input {
			if escaped {
				current.append(ch)
				escaped = false
			} else if ch == "\\" {
				escaped = true
			} else if ch == separator {
				parts.append(current)
				current = ""
			} else {
				current.append(ch)
			}
		}
		if escaped {
			current.append("\\")
		}
		parts.append(current)
		return parts
	}

	private static func parseSMS(body: String) -> SMSPayload? {
		guard !body.isEmpty else { return nil }
		if let colon = body.firstIndex(of: ":") {
			let number = String(body[..<colon])
			let message = String(body[body.index(after: colon)...])
			return SMSPayload(number: number, body: message.isEmpty ? nil : message)
		}
		return SMSPayload(number: body, body: nil)
	}

	private static func parseMailto(_ content: String) -> EmailPayload? {
		guard let components = URLComponents(string: content) else { return nil }
		// Decoded so `mailto:user%40example.com` is recognized.
		guard let address = components.percentEncodedPath.removingPercentEncoding else { return nil }
		guard address.contains("@") else { return nil }
		let subject = components.queryItems?.first(where: { $0.name == "subject" })?.value
		let body = components.queryItems?.first(where: { $0.name == "body" })?.value
		return EmailPayload(address: address, subject: subject, body: body)
	}

	private static func parseGeo(body: String) -> (latitude: Double, longitude: Double)? {
		let coordString = body.split(separator: "?", maxSplits: 1).first.map(String.init) ?? body
		let parts = coordString.split(separator: ",")
		guard parts.count >= 2,
		      let lat = Double(parts[0]),
		      let lon = Double(parts[1]) else { return nil }
		guard (-90.0 ... 90.0).contains(lat), (-180.0 ... 180.0).contains(lon) else {
			return nil
		}
		return (lat, lon)
	}
}
