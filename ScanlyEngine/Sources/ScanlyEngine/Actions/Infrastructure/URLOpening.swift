//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

/// Opens a URL through the system. Modeled as a protocol so the
/// result-sheet URL action can be verified with a spy instead of
/// handing real URLs to the OS during tests.
@MainActor
public protocol URLOpening {
	/// Hands `url` to the system to open in the appropriate app.
	///
	/// - Parameter url: The URL to open.
	/// - Returns: `true` when the system opened the URL, `false` when no
	///   installed app could handle it.
	@discardableResult
	func open(_ url: URL) async -> Bool
}

/// `URLOpening` backed by `UIApplication.shared`.
@MainActor
public struct SystemURLOpener: URLOpening {
	public init() {}

	@discardableResult
	public func open(_ url: URL) async -> Bool {
		await UIApplication.shared.open(url)
	}
}
