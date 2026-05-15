//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine

/// Records every string copied through `Pasteboard` so tests can assert
/// what a result-sheet action placed on the pasteboard.
@MainActor
public final class PasteboardSpy: Pasteboard {
	public private(set) var copiedStrings: [String] = []

	public init() {}

	public func copy(_ string: String) {
		copiedStrings.append(string)
	}
}
