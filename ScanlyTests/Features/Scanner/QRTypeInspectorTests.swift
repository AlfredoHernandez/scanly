//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

struct QRTypeInspectorTests {
	// MARK: - URL

	@Test
	func `url rows mirror URLBreakdown, including verbatim query param names`() throws {
		let url = try #require(URL(string: "https://api.example.com:8443/v1/users?page=2&lang=es#top"))
		let rows = QRType.url(url).inspectorRows
		#expect(rows == [
			.localized("scanner.result.url.scheme", value: "https"),
			.localized("scanner.result.url.host", value: "api.example.com"),
			.localized("scanner.result.url.port", value: "8443"),
			.localized("scanner.result.url.path", value: "/v1/users"),
			.verbatim("page", value: "2"),
			.verbatim("lang", value: "es"),
			.localized("scanner.result.url.fragment", value: "top"),
		])
	}

	// MARK: - WiFi

	@Test
	func `wifi rows include password and hidden flag when set`() {
		let credentials = WiFiCredentials(ssid: "HomeNet", password: "s3cret", security: .wpa, isHidden: true)
		let rows = QRType.wifi(credentials).inspectorRows
		#expect(rows == [
			.localized("scanner.result.wifi.ssid", value: "HomeNet"),
			.localized("scanner.result.wifi.password", value: "s3cret"),
			.localized("scanner.result.wifi.security", value: "WPA/WPA2/WPA3"),
			.localized(
				"scanner.result.wifi.hidden",
				value: String(localized: "scanner.result.wifi.hidden.yes"),
			),
		])
	}

	@Test
	func `open wifi without password omits password row and reports localized security`() {
		let credentials = WiFiCredentials(ssid: "Cafe", password: nil, security: .none, isHidden: false)
		let rows = QRType.wifi(credentials).inspectorRows
		#expect(rows == [
			.localized("scanner.result.wifi.ssid", value: "Cafe"),
			.localized("scanner.result.wifi.security", value: String(localized: "scanner.result.wifi.security.none")),
		])
	}

	// MARK: - Email

	@Test
	func `email rows omit empty subject and body`() {
		let payload = EmailPayload(address: "a@b.com", subject: nil, body: nil)
		#expect(QRType.email(payload).inspectorRows == [
			.localized("scanner.result.email.address", value: "a@b.com"),
		])
	}

	@Test
	func `email rows include subject and body when provided`() {
		let payload = EmailPayload(address: "a@b.com", subject: "Hi", body: "Hello world")
		#expect(QRType.email(payload).inspectorRows == [
			.localized("scanner.result.email.address", value: "a@b.com"),
			.localized("scanner.result.email.subject", value: "Hi"),
			.localized("scanner.result.email.body", value: "Hello world"),
		])
	}

	// MARK: - SMS

	@Test
	func `sms rows include body only when present`() {
		#expect(QRType.sms(SMSPayload(number: "+521234", body: nil)).inspectorRows == [
			.localized("scanner.result.sms.number", value: "+521234"),
		])
		#expect(QRType.sms(SMSPayload(number: "+521234", body: "hola")).inspectorRows == [
			.localized("scanner.result.sms.number", value: "+521234"),
			.localized("scanner.result.sms.body", value: "hola"),
		])
	}

	// MARK: - Phone

	@Test
	func `phone row surfaces the number`() {
		#expect(QRType.phone("+525555555555").inspectorRows == [
			.localized("scanner.result.phone.number", value: "+525555555555"),
		])
	}

	// MARK: - Location

	@Test
	func `location rows format latitude and longitude`() {
		let rows = QRType.location(latitude: 19.4326, longitude: -99.1332).inspectorRows
		#expect(rows.count == 2)
		#expect(rows[0] == .localized("scanner.result.location.latitude", value: "19.4326"))
		#expect(rows[1] == .localized("scanner.result.location.longitude", value: "-99.1332"))
	}

	// MARK: - No-structure cases

	@Test
	func `text scan has no inspector rows`() {
		#expect(QRType.text("hello world").inspectorRows.isEmpty)
	}

	@Test
	func `contact scan currently has no inspector rows`() {
		#expect(QRType.contact(vCard: "BEGIN:VCARD\nFN:Test\nEND:VCARD").inspectorRows.isEmpty)
	}
}
