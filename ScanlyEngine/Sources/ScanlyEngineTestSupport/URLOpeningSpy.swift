//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

/// Records every URL handed to `URLOpening` so tests can assert which
/// URL a result-sheet action opened, and stubs the system success flag.
@MainActor
public final class URLOpeningSpy: URLOpening {
	public private(set) var openedURLs: [URL] = []

	/// Stubbed value returned by `open(_:)`.
	public var openSucceeds = true

	public init() {}

	@discardableResult
	public func open(_ url: URL) async -> Bool {
		openedURLs.append(url)
		return openSucceeds
	}
}
