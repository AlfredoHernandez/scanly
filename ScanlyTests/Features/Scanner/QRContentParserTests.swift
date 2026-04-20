//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

struct QRContentParserTests {
	private let sut = QRContentParser()

	// MARK: - URL

	@Test
	func `parses https:// as .url`() throws {
		let result = sut.parse("https://example.com")
		#expect(try result == .url(#require(URL(string: "https://example.com"))))
	}

	@Test
	func `parses http:// as .url`() throws {
		let result = sut.parse("http://example.com/path?q=1")
		#expect(try result == .url(#require(URL(string: "http://example.com/path?q=1"))))
	}

	// MARK: - Phone

	@Test
	func `parses tel: as .phone`() {
		#expect(sut.parse("tel:+14155551212") == .phone("+14155551212"))
	}

	@Test
	func `parses TEL: case-insensitively`() {
		#expect(sut.parse("TEL:5551212") == .phone("5551212"))
	}

	@Test
	func `tel: value is trimmed`() {
		#expect(sut.parse("tel:  +14155551212  ") == .phone("+14155551212"))
	}

	@Test
	func `parses MAILTO: case-insensitively`() {
		let expected = EmailPayload(address: "user@example.com", subject: nil, body: nil)
		#expect(sut.parse("MAILTO:user@example.com") == .email(expected))
	}

	@Test
	func `parses GEO: case-insensitively`() {
		#expect(sut.parse("GEO:37.7749,-122.4194") == .location(latitude: 37.7749, longitude: -122.4194))
	}

	@Test
	func `parses SMS: case-insensitively`() {
		#expect(sut.parse("SMS:+14155551212") == .sms(SMSPayload(number: "+14155551212", body: nil)))
	}

	@Test
	func `rejects WIFI: without SSID`() {
		#expect(sut.parse("WIFI:T:WPA;P:secret;;") == .text("WIFI:T:WPA;P:secret;;"))
	}

	@Test
	func `parses wifi: lowercased`() {
		let expected = WiFiCredentials(ssid: "Home", password: "pw", security: .wpa, isHidden: false)
		#expect(sut.parse("wifi:T:WPA;S:Home;P:pw;;") == .wifi(expected))
	}

	// MARK: - SMS

	@Test
	func `parses sms: with number only`() {
		#expect(sut.parse("sms:+14155551212") == .sms(SMSPayload(number: "+14155551212", body: nil)))
	}

	@Test
	func `sms: with empty body after colon yields nil body`() {
		let expected = SMSPayload(number: "+15551212", body: nil)
		#expect(sut.parse("sms:+15551212:") == .sms(expected))
	}

	@Test
	func `parses smsto: with body`() {
		let expected = SMSPayload(number: "+14155551212", body: "hello world")
		#expect(sut.parse("smsto:+14155551212:hello world") == .sms(expected))
	}

	@Test
	func `smsto: is not accidentally matched by sms: branch`() {
		// Longer prefix must be checked first: "smsto:" shares its head with "sms:".
		let expected = SMSPayload(number: "+14155551212", body: "hi")
		#expect(sut.parse("smsto:+14155551212:hi") == .sms(expected))
	}

	// MARK: - Email

	@Test
	func `parses mailto: with address only`() {
		let expected = EmailPayload(address: "user@example.com", subject: nil, body: nil)
		#expect(sut.parse("mailto:user@example.com") == .email(expected))
	}

	@Test
	func `rejects mailto: without @ in address`() {
		#expect(sut.parse("mailto:notanemail") == .text("mailto:notanemail"))
	}

	@Test
	func `rejects mailto: with only a query string`() {
		#expect(sut.parse("mailto:?subject=hi") == .text("mailto:?subject=hi"))
	}

	@Test
	func `parses mailto: with percent-encoded @ in address`() {
		let expected = EmailPayload(address: "user@example.com", subject: nil, body: nil)
		#expect(sut.parse("mailto:user%40example.com") == .email(expected))
	}

	@Test
	func `parses mailto: with subject and body`() {
		let input = "mailto:user@example.com?subject=Hi&body=How%20are%20you"
		let expected = EmailPayload(address: "user@example.com", subject: "Hi", body: "How are you")
		#expect(sut.parse(input) == .email(expected))
	}

	// MARK: - Wi-Fi

	@Test
	func `parses WIFI: WPA network`() {
		let input = "WIFI:T:WPA;S:MyNetwork;P:secret123;;"
		let expected = WiFiCredentials(
			ssid: "MyNetwork",
			password: "secret123",
			security: .wpa,
			isHidden: false,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	@Test
	func `parses WIFI: open network with no password`() {
		let input = "WIFI:T:nopass;S:Guest;P:;;"
		let expected = WiFiCredentials(
			ssid: "Guest",
			password: nil,
			security: .none,
			isHidden: false,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	@Test
	func `preserves trailing unpaired backslash in WIFI password`() {
		let input = #"WIFI:T:WPA;S:Net;P:abc\"#
		let expected = WiFiCredentials(
			ssid: "Net",
			password: #"abc\"#,
			security: .wpa,
			isHidden: false,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	@Test
	func `parses WIFI: with escaped semicolons in password`() {
		let input = #"WIFI:T:WPA;S:Net;P:pa\;ss\\word;;"#
		let expected = WiFiCredentials(
			ssid: "Net",
			password: #"pa;ss\word"#,
			security: .wpa,
			isHidden: false,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	@Test
	func `parses WIFI: hidden network`() {
		let input = "WIFI:T:WPA;S:Hidden;P:pass;H:true;;"
		let expected = WiFiCredentials(
			ssid: "Hidden",
			password: "pass",
			security: .wpa,
			isHidden: true,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	@Test
	func `parses WIFI: with explicit H:false`() {
		let input = "WIFI:T:WPA;S:Net;P:pass;H:false;;"
		let expected = WiFiCredentials(
			ssid: "Net",
			password: "pass",
			security: .wpa,
			isHidden: false,
		)
		#expect(sut.parse(input) == .wifi(expected))
	}

	// MARK: - vCard

	@Test
	func `parses BEGIN:VCARD as .contact`() {
		let input = """
		BEGIN:VCARD
		VERSION:3.0
		FN:Jane Doe
		TEL:+14155551212
		END:VCARD
		"""
		#expect(sut.parse(input) == .contact(vCard: input))
	}

	// MARK: - Geo

	@Test
	func `parses geo: as .location`() {
		#expect(sut.parse("geo:37.7749,-122.4194") == .location(latitude: 37.7749, longitude: -122.4194))
	}

	@Test
	func `parses geo: with altitude ignored`() {
		#expect(sut.parse("geo:37.7749,-122.4194,30") == .location(latitude: 37.7749, longitude: -122.4194))
	}

	@Test
	func `parses geo: with garbage after lat,lon`() {
		// The geo: URI spec leaves the 3rd+ parts as optional altitude/CRS;
		// the parser intentionally accepts any trailing junk.
		#expect(sut.parse("geo:37.7749,-122.4194,notanumber") == .location(latitude: 37.7749, longitude: -122.4194))
	}

	@Test
	func `rejects geo: with latitude out of range`() {
		#expect(sut.parse("geo:200,0") == .text("geo:200,0"))
	}

	@Test
	func `rejects geo: with longitude out of range`() {
		#expect(sut.parse("geo:0,400") == .text("geo:0,400"))
	}

	@Test
	func `rejects geo: with NaN coordinates`() {
		#expect(sut.parse("geo:NaN,NaN") == .text("geo:NaN,NaN"))
	}

	@Test
	func `accepts geo: at boundary values`() {
		#expect(sut.parse("geo:90,180") == .location(latitude: 90, longitude: 180))
		#expect(sut.parse("geo:-90,-180") == .location(latitude: -90, longitude: -180))
	}

	// MARK: - Generic scheme URLs

	@Test
	func `ftp scheme is recognized as .url`() throws {
		let raw = "ftp://example.com/file"
		#expect(try sut.parse(raw) == .url(#require(URL(string: raw))))
	}

	@Test
	func `otpauth scheme is recognized as .url`() throws {
		let raw = "otpauth://totp/Issuer:acc?secret=X"
		#expect(try sut.parse(raw) == .url(#require(URL(string: raw))))
	}

	@Test
	func `arbitrary custom app scheme is recognized as .url`() throws {
		let raw = "myapp://open?target=home"
		#expect(try sut.parse(raw) == .url(#require(URL(string: raw))))
	}

	@Test
	func `string with a colon but no scheme does not become .url`() {
		#expect(sut.parse("price: $10") == .text("price: $10"))
	}

	// MARK: - Fallback

	@Test
	func `falls back to .text for plain strings`() {
		#expect(sut.parse("just some random text") == .text("just some random text"))
	}

	@Test
	func `trims surrounding whitespace before classifying`() throws {
		#expect(try sut.parse("  https://example.com  ") == .url(#require(URL(string: "https://example.com"))))
	}
}
