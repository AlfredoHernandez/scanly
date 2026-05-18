//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import ScanlyEngineTestSupport
import Testing

struct ScanResultPrimaryActionTests {
	// MARK: - Per-type mapping (§10.3.2)

	@Test
	func `url scan maps to openURL carrying the scanned URL`() throws {
		let url = try #require(URL(string: "https://example.com/page"))
		#expect(ScanResultPrimaryAction(for: anyResult(type: .url(url))) == .openURL(url))
	}

	@Test
	func `wifi scan maps to connectWiFi carrying the credentials`() {
		let credentials = WiFiCredentials(ssid: "Home", password: "secret", security: .wpa)
		#expect(ScanResultPrimaryAction(for: anyResult(type: .wifi(credentials))) == .connectWiFi(credentials))
	}

	@Test
	func `contact scan maps to addContact carrying the vCard`() {
		let vCard = "BEGIN:VCARD\nFN:Jane\nEND:VCARD"
		#expect(ScanResultPrimaryAction(for: anyResult(type: .contact(vCard: vCard))) == .addContact(vCard: vCard))
	}

	@Test
	func `phone scan maps to call carrying the number`() {
		#expect(ScanResultPrimaryAction(for: anyResult(type: .phone("+14155551212"))) == .call("+14155551212"))
	}

	@Test
	func `email scan maps to composeEmail carrying the payload`() {
		let payload = EmailPayload(address: "me@example.com", subject: "Hi", body: "Hello")
		#expect(ScanResultPrimaryAction(for: anyResult(type: .email(payload))) == .composeEmail(payload))
	}

	@Test
	func `sms scan maps to sendSMS carrying the payload`() {
		let payload = SMSPayload(number: "+14155551212", body: "hola")
		#expect(ScanResultPrimaryAction(for: anyResult(type: .sms(payload))) == .sendSMS(payload))
	}

	@Test
	func `location scan maps to openMaps carrying the coordinate`() {
		let result = anyResult(type: .location(latitude: 19.4326, longitude: -99.1332))
		#expect(ScanResultPrimaryAction(for: result) == .openMaps(latitude: 19.4326, longitude: -99.1332))
	}

	// MARK: - Text collapses onto Share

	@Test
	func `text scan maps to share carrying the raw content, not the parsed text`() {
		let result = anyResult(rawContent: "raw scanned payload", type: .text("parsed text"))
		#expect(ScanResultPrimaryAction(for: result) == .share("raw scanned payload"))
	}

	// MARK: - Label keys (§10.3.2)

	@Test(arguments: ActionCase.allCases)
	func `labelKey is namespaced under scanner action`(actionCase: ActionCase) throws {
		try #expect(actionCase.makeSUT().labelKey == actionCase.expectedKey)
	}

	// MARK: - Helpers

	/// One representative `ScanResultPrimaryAction` per case. Modeled as a
	/// `CaseIterable` enum so an action added without label-key coverage
	/// fails to compile rather than slipping through untested.
	enum ActionCase: CaseIterable {
		case openURL, connectWiFi, addContact, call, composeEmail, sendSMS, openMaps, share

		func makeSUT() throws -> ScanResultPrimaryAction {
			switch self {
			case .openURL:
				try .openURL(#require(URL(string: "https://example.com")))

			case .connectWiFi:
				.connectWiFi(WiFiCredentials(ssid: "ssid", security: .none))

			case .addContact:
				.addContact(vCard: "BEGIN:VCARD\nEND:VCARD")

			case .call:
				.call("+14155551212")

			case .composeEmail:
				.composeEmail(EmailPayload(address: "me@example.com"))

			case .sendSMS:
				.sendSMS(SMSPayload(number: "+14155551212"))

			case .openMaps:
				.openMaps(latitude: 0, longitude: 0)

			case .share:
				.share("text")
			}
		}

		var expectedKey: LocalizedStringResource {
			switch self {
			case .openURL: "scanner.action.open_url"

			case .connectWiFi: "scanner.action.connect_wifi"

			case .addContact: "scanner.action.add_contact"

			case .call: "scanner.action.call"

			case .composeEmail: "scanner.action.compose_email"

			case .sendSMS: "scanner.action.send_sms"

			case .openMaps: "scanner.action.open_maps"

			case .share: "scanner.action.share"
			}
		}
	}
}
