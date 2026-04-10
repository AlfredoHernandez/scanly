//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

struct QRTypeDiscriminatorTests {
	/// Enum (rather than tuples) keeps the `@Test` arguments list trivially `Sendable`.
	enum Case: String, CaseIterable {
		case url, wifi, contact, phone, email, sms, location, text

		var sut: QRType {
			switch self {
			case .url:
				.url(URL(string: "https://example.com/secret?token=abc")!)

			case .wifi:
				.wifi(WiFiCredentials(ssid: "Home", password: "hunter2", security: .wpa, isHidden: false))

			case .contact:
				.contact(vCard: "BEGIN:VCARD\nFN:Jane\nEND:VCARD")

			case .phone:
				.phone("+14155551212")

			case .email:
				.email(EmailPayload(address: "me@example.com", subject: "Secret", body: "confidential"))

			case .sms:
				.sms(SMSPayload(number: "+14155551212", body: "secret"))

			case .location:
				.location(latitude: 37.7749, longitude: -122.4194)

			case .text:
				.text("sensitive note")
			}
		}
	}

	@Test(arguments: Case.allCases)
	func `discriminator matches case name`(testCase: Case) {
		#expect(testCase.sut.discriminator == testCase.rawValue)
	}

	@Test
	func `discriminator never includes associated values`() throws {
		let secret = "hunter2-very-secret"
		let cases: [QRType] = try [
			.url(#require(URL(string: "https://example.com?token=\(secret)"))),
			.wifi(WiFiCredentials(ssid: "x", password: secret, security: .wpa, isHidden: false)),
			.contact(vCard: secret),
			.phone(secret),
			.email(EmailPayload(address: secret, subject: secret, body: secret)),
			.sms(SMSPayload(number: secret, body: secret)),
			.text(secret),
		]
		for sut in cases {
			#expect(!sut.discriminator.contains(secret))
		}
	}
}
