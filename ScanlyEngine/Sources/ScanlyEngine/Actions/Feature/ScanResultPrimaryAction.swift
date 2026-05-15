//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// The single prominent call-to-action shown at the top of the scan
/// result sheet, derived from a `ScanResult` per §10.3.2 of the product
/// scope.
///
/// Each case carries exactly the payload its system action needs, so the
/// presentation layer can pattern-match over it to drive the matching
/// adapter without re-inspecting the original `QRType`. A `.text` scan
/// has no richer action than sharing its content, so it collapses onto
/// `.share`.
public nonisolated enum ScanResultPrimaryAction: Equatable, Sendable {
	/// Open a web or custom-scheme URL. The presentation layer gates this
	/// behind a confirmation alert (§10.3.3).
	case openURL(URL)

	/// Join a Wi-Fi network from scanned credentials.
	case connectWiFi(WiFiCredentials)

	/// Add a scanned vCard to the address book.
	case addContact(vCard: String)

	/// Place a phone call to a scanned number.
	case call(String)

	/// Open a mail composer prefilled from the scanned payload.
	case composeEmail(EmailPayload)

	/// Open a message composer prefilled from the scanned payload.
	case sendSMS(SMSPayload)

	/// Show a scanned coordinate in Maps.
	case openMaps(latitude: Double, longitude: Double)

	/// Share raw scanned content through the system share sheet.
	case share(String)

	/// Derives the primary action for a scan result following the
	/// per-type mapping in §10.3.2.
	///
	/// - Parameter result: The accepted scan to derive the action from.
	public init(for result: ScanResult) {
		switch result.type {
		case let .url(url):
			self = .openURL(url)

		case let .wifi(credentials):
			self = .connectWiFi(credentials)

		case let .contact(vCard):
			self = .addContact(vCard: vCard)

		case let .phone(number):
			self = .call(number)

		case let .email(payload):
			self = .composeEmail(payload)

		case let .sms(payload):
			self = .sendSMS(payload)

		case let .location(latitude, longitude):
			self = .openMaps(latitude: latitude, longitude: longitude)

		case .text:
			// Share always carries `rawContent`, never the parsed text,
			// so the recipient gets the exact scanned payload (§10.3.4).
			self = .share(result.rawContent)
		}
	}

	/// String-catalog key for the button's title, namespaced
	/// `scanner.action.*`.
	public var labelKey: LocalizedStringResource {
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
