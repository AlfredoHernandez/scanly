//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

/// Places a phone call. Modeled as a protocol so the result-sheet call
/// action can be verified with a spy instead of opening the system
/// dialer during tests.
@MainActor
public protocol PhoneCallPlacing {
	/// Places a call to `number` by opening its `tel:` URL.
	///
	/// - Parameter number: The phone number to dial.
	/// - Returns: `true` when the system could place the call; `false`
	///   on devices without telephony (e.g. Wi-Fi-only iPads).
	@discardableResult
	func call(_ number: String) async -> Bool
}

/// `PhoneCallPlacing` backed by opening a `tel:` URL through
/// `UIApplication.shared`.
@MainActor
public struct SystemPhoneCaller: PhoneCallPlacing {
	public init() {}

	@discardableResult
	public func call(_ number: String) async -> Bool {
		// Scanned numbers often carry spaces, dashes, or parentheses;
		// keep only the characters a `tel:` URL can dial.
		let dialable = number.filter { $0.isNumber || "+*#,;".contains($0) }
		guard !dialable.isEmpty, let url = URL(string: "tel:\(dialable)") else {
			return false
		}
		return await UIApplication.shared.open(url)
	}
}
