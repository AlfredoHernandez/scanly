//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated struct WiFiCredentials: Equatable {
	let ssid: String
	let password: String?
	let security: WiFiSecurity
	let isHidden: Bool
}

nonisolated enum WiFiSecurity: String, Equatable {
	case wpa
	case wep
	case none
}
