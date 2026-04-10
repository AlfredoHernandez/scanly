//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated enum QRType: Equatable {
	case url(URL)
	case wifi(WiFiCredentials)
	case contact(vCard: String)
	case phone(String)
	case email(EmailPayload)
	case sms(SMSPayload)
	case location(latitude: Double, longitude: Double)
	case text(String)

	/// Case name only; never includes associated values to keep secrets out of logs.
	var discriminator: String {
		switch self {
		case .url: "url"

		case .wifi: "wifi"

		case .contact: "contact"

		case .phone: "phone"

		case .email: "email"

		case .sms: "sms"

		case .location: "location"

		case .text: "text"
		}
	}
}
