//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

/// Abstraction over the system pasteboard so result-sheet copy actions
/// can be verified with a spy instead of mutating the real
/// `UIPasteboard` during tests.
@MainActor
public protocol Pasteboard {
	/// Replaces the pasteboard's contents with `string`.
	///
	/// - Parameter string: The text to place on the pasteboard.
	func copy(_ string: String)
}

/// `Pasteboard` backed by `UIPasteboard.general`.
public struct SystemPasteboard: Pasteboard {
	public init() {}

	public func copy(_ string: String) {
		UIPasteboard.general.string = string
	}
}
