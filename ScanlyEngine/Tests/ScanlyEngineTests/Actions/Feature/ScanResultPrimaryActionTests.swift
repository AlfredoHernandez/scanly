//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import Testing

struct ScanResultPrimaryActionTests {
	// MARK: - Per-type mapping (§10.3.2)

	@Test
	func `url scan maps to openURL carrying the scanned URL`() throws {
		let url = try #require(URL(string: "https://example.com/page"))
		#expect(ScanResultPrimaryAction(for: makeResult(.url(url))) == .openURL(url))
	}

	@Test
	func `wifi scan maps to connectWiFi carrying the credentials`() {
		let credentials = WiFiCredentials(ssid: "Home", password: "secret", security: .wpa)
		#expect(ScanResultPrimaryAction(for: makeResult(.wifi(credentials))) == .connectWiFi(credentials))
	}

	@Test
	func `contact scan maps to addContact carrying the vCard`() {
		let vCard = "BEGIN:VCARD\nFN:Jane\nEND:VCARD"
		#expect(ScanResultPrimaryAction(for: makeResult(.contact(vCard: vCard))) == .addContact(vCard: vCard))
	}

	@Test
	func `phone scan maps to call carrying the number`() {
		#expect(ScanResultPrimaryAction(for: makeResult(.phone("+14155551212"))) == .call("+14155551212"))
	}

	@Test
	func `email scan maps to composeEmail carrying the payload`() {
		let payload = EmailPayload(address: "me@example.com", subject: "Hi", body: "Hello")
		#expect(ScanResultPrimaryAction(for: makeResult(.email(payload))) == .composeEmail(payload))
	}

	@Test
	func `sms scan maps to sendSMS carrying the payload`() {
		let payload = SMSPayload(number: "+14155551212", body: "hola")
		#expect(ScanResultPrimaryAction(for: makeResult(.sms(payload))) == .sendSMS(payload))
	}

	@Test
	func `location scan maps to openMaps carrying the coordinate`() {
		let result = makeResult(.location(latitude: 19.4326, longitude: -99.1332))
		#expect(ScanResultPrimaryAction(for: result) == .openMaps(latitude: 19.4326, longitude: -99.1332))
	}

	// MARK: - Text collapses onto Share

	@Test
	func `text scan maps to share carrying the raw content, not the parsed text`() {
		let result = makeResult(.text("parsed text"), rawContent: "raw scanned payload")
		#expect(ScanResultPrimaryAction(for: result) == .share("raw scanned payload"))
	}

	// MARK: - Label keys (§10.3.2)

	@Test
	func `label keys are namespaced under scanner action`() throws {
		let url = try #require(URL(string: "https://example.com"))
		#expect(ScanResultPrimaryAction.openURL(url).labelKey == "scanner.action.open_url")
		#expect(ScanResultPrimaryAction.connectWiFi(anyWiFi()).labelKey == "scanner.action.connect_wifi")
		#expect(ScanResultPrimaryAction.addContact(vCard: "x").labelKey == "scanner.action.add_contact")
		#expect(ScanResultPrimaryAction.call("x").labelKey == "scanner.action.call")
		#expect(ScanResultPrimaryAction.composeEmail(EmailPayload(address: "a@b.com")).labelKey == "scanner.action.compose_email")
		#expect(ScanResultPrimaryAction.sendSMS(SMSPayload(number: "x")).labelKey == "scanner.action.send_sms")
		#expect(ScanResultPrimaryAction.openMaps(latitude: 0, longitude: 0).labelKey == "scanner.action.open_maps")
		#expect(ScanResultPrimaryAction.share("x").labelKey == "scanner.action.share")
	}

	// MARK: - Helpers

	private func makeResult(_ type: QRType, rawContent: String = "raw-content") -> ScanResult {
		ScanResult(rawContent: rawContent, type: type, format: .qr, scannedAt: Date(timeIntervalSince1970: 0))
	}

	private func anyWiFi() -> WiFiCredentials {
		WiFiCredentials(ssid: "ssid", password: nil, security: .none)
	}
}
