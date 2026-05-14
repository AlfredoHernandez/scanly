//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

public nonisolated struct WiFiCredentials: Equatable, Sendable {
	public let ssid: String
	public let password: String?
	public let security: WiFiSecurity
	public let isHidden: Bool

	public init(ssid: String, password: String? = nil, security: WiFiSecurity, isHidden: Bool = false) {
		self.ssid = ssid
		self.password = password
		self.security = security
		self.isHidden = isHidden
	}
}

public nonisolated enum WiFiSecurity: String, Equatable, Sendable {
	case wpa
	case wep
	case none
}
