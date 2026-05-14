//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import ScanlyEngineTestSupport
import Testing

/// `HistorySearch` is `nonisolated`, so the suite has no actor
/// isolation either — tests can run on any executor and the framework
/// is free to parallelise them.
struct HistorySearchTests {
	// MARK: - Query handling

	@Test
	func `empty query returns the input unchanged`() {
		let inputs = [anyResult(rawContent: "a"), anyResult(rawContent: "b")]

		let filtered = HistorySearch.filter(inputs, query: "")

		#expect(filtered.map(\.rawContent) == ["a", "b"])
	}

	@Test
	func `whitespace-only query returns the input unchanged`() {
		let inputs = [anyResult(rawContent: "a")]

		#expect(HistorySearch.filter(inputs, query: "   \n\t").count == 1)
	}

	@Test
	func `filter preserves the input ordering of survivors`() {
		// `HistorySearch` is sort-agnostic — callers sort upstream.
		// The filter must not re-order matches relative to inputs.
		let inputs = [
			anyResult(rawContent: "match-c"),
			anyResult(rawContent: "miss"),
			anyResult(rawContent: "match-a"),
			anyResult(rawContent: "match-b"),
		]

		let filtered = HistorySearch.filter(inputs, query: "match")

		#expect(filtered.map(\.rawContent) == ["match-c", "match-a", "match-b"])
	}

	// MARK: - Match modes

	@Test
	func `match is case-insensitive`() {
		let inputs = [textResult("HELLO World")]

		#expect(HistorySearch.filter(inputs, query: "hello").count == 1)
		#expect(HistorySearch.filter(inputs, query: "WORLD").count == 1)
	}

	@Test
	func `match is diacritic-insensitive`() {
		let inputs = [textResult("Café Münchën")]

		#expect(HistorySearch.filter(inputs, query: "cafe").count == 1)
		#expect(HistorySearch.filter(inputs, query: "MUNCHEN").count == 1)
	}

	@Test
	func `non-matching query returns an empty result`() {
		let inputs = [textResult("hello")]

		#expect(HistorySearch.filter(inputs, query: "missing").isEmpty)
	}

	// MARK: - .text type — rawContent is the index

	@Test
	func `text matches by rawContent substring`() {
		let inputs = [textResult("the quick brown fox")]

		#expect(HistorySearch.filter(inputs, query: "quick").count == 1)
	}

	// MARK: - .url type — host is matched, path/query/fragment are not

	@Test
	func `url matches by host substring`() {
		let inputs = [urlResult("https://example.com/page?x=1#top")]

		#expect(HistorySearch.filter(inputs, query: "example").count == 1)
	}

	@Test
	func `url does not match by path even though path is in rawContent`() {
		// §10.2.5 excludes URL path from search. Even though the path
		// string appears in `rawContent`, the algorithm must not
		// surface this row when the query only matches the path.
		let inputs = [urlResult("https://example.com/secret-page")]

		#expect(HistorySearch.filter(inputs, query: "secret-page").isEmpty, "URL path is excluded from search per §10.2.5")
	}

	@Test
	func `url does not match by query string even though it is in rawContent`() {
		let inputs = [urlResult("https://example.com/path?token=abc123")]

		#expect(HistorySearch.filter(inputs, query: "abc123").isEmpty, "URL query is excluded from search per §10.2.5")
	}

	@Test
	func `url does not match by fragment even though it is in rawContent`() {
		let inputs = [urlResult("https://example.com#deep-link-anchor")]

		#expect(HistorySearch.filter(inputs, query: "deep-link-anchor").isEmpty, "URL fragment is excluded from search per §10.2.5")
	}

	@Test
	func `url with no host (opaque scheme) does not match its rawContent`() {
		let inputs = [urlResult("mailto:foo@bar.com")]

		#expect(HistorySearch.filter(inputs, query: "foo").isEmpty, "Without a host the URL has no indexed field; rawContent is not a fallback for .url")
	}

	// MARK: - .wifi type — SSID is matched, password is not

	@Test
	func `wifi matches by SSID substring`() {
		let credentials = WiFiCredentials(ssid: "GuestNetwork", password: "hunter2", security: .wpa, isHidden: false)
		let inputs = [wifiResult(credentials: credentials, rawContent: "WIFI:S:GuestNetwork;T:WPA;P:hunter2;H:;")]

		#expect(HistorySearch.filter(inputs, query: "guest").count == 1)
	}

	@Test
	func `wifi does not match by password even though password appears in rawContent`() {
		// §10.2.5 excludes Wi-Fi passwords from search. The password
		// is present in `rawContent` (the literal WIFI:...;P:hunter2;
		// payload) but must not surface a row when the user types it.
		let credentials = WiFiCredentials(ssid: "GuestNetwork", password: "hunter2", security: .wpa, isHidden: false)
		let inputs = [wifiResult(credentials: credentials, rawContent: "WIFI:S:GuestNetwork;T:WPA;P:hunter2;H:;")]

		#expect(HistorySearch.filter(inputs, query: "hunter2").isEmpty, "Wi-Fi password is excluded from search per §10.2.5")
	}

	// MARK: - .email type — address is matched, subject/body are not

	@Test
	func `email matches by address substring`() {
		let payload = EmailPayload(address: "alice@example.com", subject: "Lunch", body: "See attached")
		let inputs = [emailResult(payload: payload, rawContent: "mailto:alice@example.com?subject=Lunch&body=See%20attached")]

		#expect(HistorySearch.filter(inputs, query: "alice").count == 1)
	}

	@Test
	func `email does not match by subject even though subject is in rawContent`() {
		let payload = EmailPayload(address: "alice@example.com", subject: "Confidential proposal", body: nil)
		let inputs = [emailResult(payload: payload, rawContent: "mailto:alice@example.com?subject=Confidential%20proposal")]

		#expect(HistorySearch.filter(inputs, query: "confidential").isEmpty, "Email subject is excluded from search per §10.2.5")
	}

	@Test
	func `email does not match by body even though body is in rawContent`() {
		let payload = EmailPayload(address: "alice@example.com", subject: nil, body: "secret message")
		let inputs = [emailResult(payload: payload, rawContent: "mailto:alice@example.com?body=secret%20message")]

		#expect(HistorySearch.filter(inputs, query: "secret").isEmpty, "Email body is excluded from search per §10.2.5")
	}

	// MARK: - .sms type — number is matched, body is not

	@Test
	func `sms matches by number substring`() {
		let payload = SMSPayload(number: "+15551234567", body: "Hi")
		let inputs = [smsResult(payload: payload, rawContent: "smsto:+15551234567:Hi")]

		#expect(HistorySearch.filter(inputs, query: "5551234").count == 1)
	}

	@Test
	func `sms does not match by body even though body is in rawContent`() {
		let payload = SMSPayload(number: "+15551234567", body: "see appendix")
		let inputs = [smsResult(payload: payload, rawContent: "smsto:+15551234567:see appendix")]

		#expect(HistorySearch.filter(inputs, query: "appendix").isEmpty, "SMS body is excluded from search per §10.2.5")
	}

	// MARK: - .phone type — number is matched

	@Test
	func `phone matches by number substring`() {
		let inputs = [phoneResult(number: "+15551234567", rawContent: "tel:+15551234567")]

		#expect(HistorySearch.filter(inputs, query: "555").count == 1)
	}

	@Test
	func `phone does not match by tel: scheme prefix even though it is in rawContent`() {
		// `rawContent` for a phone payload is `"tel:+<number>"`. The
		// indexed value is the number alone — typing `"tel:"` must
		// not surface every phone row in the store. This pairs with
		// the URL/Wi-Fi/email exclusion tests above: every structured
		// type keeps a literal rawContent prefix out of search.
		let inputs = [phoneResult(number: "+15551234567", rawContent: "tel:+15551234567")]

		#expect(HistorySearch.filter(inputs, query: "tel:").isEmpty, "Phone scheme prefix is not an indexed field per §10.2.5")
	}

	// MARK: - .location type — formatted coordinates are matched

	@Test
	func `location matches by formatted latitude`() {
		let inputs = [locationResult(latitude: 37.7749, longitude: -122.4194, rawContent: "geo:37.7749,-122.4194")]

		#expect(HistorySearch.filter(inputs, query: "37.77").count == 1)
	}

	@Test
	func `location matches by formatted longitude`() {
		let inputs = [locationResult(latitude: 37.7749, longitude: -122.4194, rawContent: "geo:37.7749,-122.4194")]

		#expect(HistorySearch.filter(inputs, query: "-122.41").count == 1)
	}

	@Test
	func `location formats coordinates with up to six fraction digits`() {
		// Mirrors the inspector formatter: the user sees the same
		// truncated representation in the detail row and the search
		// bar matches it identically.
		let inputs = [locationResult(latitude: 37.123456789, longitude: -122.987654321, rawContent: "geo:37.123456789,-122.987654321")]

		#expect(HistorySearch.filter(inputs, query: "37.123457").count == 1)
		#expect(HistorySearch.filter(inputs, query: "37.123456789").isEmpty, "Indexed value rounds to 6 fraction digits")
	}

	// MARK: - .contact type — vCard rawContent is indexed (v1.0 caveat)

	@Test
	func `contact matches by name embedded in vCard rawContent`() {
		let vCard = "BEGIN:VCARD\nVERSION:3.0\nFN:Alice Smith\nTEL:+15551234567\nEMAIL:alice@example.com\nEND:VCARD"
		let inputs = [contactResult(vCard: vCard)]

		#expect(HistorySearch.filter(inputs, query: "Alice").count == 1)
	}

	@Test
	func `contact matches by phone embedded in vCard rawContent`() {
		let vCard = "BEGIN:VCARD\nVERSION:3.0\nFN:Alice Smith\nTEL:+15551234567\nEND:VCARD"
		let inputs = [contactResult(vCard: vCard)]

		#expect(HistorySearch.filter(inputs, query: "555").count == 1)
	}

	// MARK: - Mixed inputs

	@Test
	func `filter returns only the matching rows out of a mixed input`() {
		let inputs = [
			textResult("hello world"),
			urlResult("https://acme.com/about"),
			textResult("acme is a company"),
			wifiResult(credentials: WiFiCredentials(ssid: "AcmeGuest", password: "x", security: .wpa, isHidden: false), rawContent: "WIFI:S:AcmeGuest;T:WPA;P:x;H:;"),
		]

		let filtered = HistorySearch.filter(inputs, query: "acme")

		#expect(filtered.map(\.rawContent) == [
			"https://acme.com/about",
			"acme is a company",
			"WIFI:S:AcmeGuest;T:WPA;P:x;H:;",
		])
	}

	// MARK: - Builders for typed results

	private func textResult(_ content: String) -> ScanResult {
		ScanResult(rawContent: content, type: .text(content), format: .qr, scannedAt: timestamp(0))
	}

	private func urlResult(_ raw: String) -> ScanResult {
		let url = URL(string: raw) ?? URL(string: "https://example.com")!
		return ScanResult(rawContent: raw, type: .url(url), format: .qr, scannedAt: timestamp(0))
	}

	private func wifiResult(credentials: WiFiCredentials, rawContent: String) -> ScanResult {
		ScanResult(rawContent: rawContent, type: .wifi(credentials), format: .qr, scannedAt: timestamp(0))
	}

	private func emailResult(payload: EmailPayload, rawContent: String) -> ScanResult {
		ScanResult(rawContent: rawContent, type: .email(payload), format: .qr, scannedAt: timestamp(0))
	}

	private func smsResult(payload: SMSPayload, rawContent: String) -> ScanResult {
		ScanResult(rawContent: rawContent, type: .sms(payload), format: .qr, scannedAt: timestamp(0))
	}

	private func phoneResult(number: String, rawContent: String) -> ScanResult {
		ScanResult(rawContent: rawContent, type: .phone(number), format: .qr, scannedAt: timestamp(0))
	}

	private func locationResult(latitude: Double, longitude: Double, rawContent: String) -> ScanResult {
		ScanResult(rawContent: rawContent, type: .location(latitude: latitude, longitude: longitude), format: .qr, scannedAt: timestamp(0))
	}

	private func contactResult(vCard: String) -> ScanResult {
		ScanResult(rawContent: vCard, type: .contact(vCard: vCard), format: .qr, scannedAt: timestamp(0))
	}
}
