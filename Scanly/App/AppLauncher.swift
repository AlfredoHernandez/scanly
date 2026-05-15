//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import SwiftUI

/// Process entry point. Picks `ScanlyApp` for normal launches and
/// `TestApp` when the binary is loaded by XCTest, so unit-test bundles
/// don't trigger the production composition root (and the live
/// SwiftData store it owns).
@main
enum AppLauncher {
	static func main() {
		if isRunningTests() {
			TestApp.main()
		} else {
			ScanlyApp.main()
		}
	}

	private static func isRunningTests() -> Bool {
		NSClassFromString("XCTestCase") != nil
	}
}
