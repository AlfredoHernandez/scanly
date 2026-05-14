//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

/// Placeholder app loaded under XCTest so the real `ScanlyApp` doesn't
/// stand up `AppDependencies` (and a live SwiftData store) during unit
/// tests. `AppLauncher` decides which one runs.
struct TestApp: App {
	var body: some Scene {
		WindowGroup {
			Text("Running Unit Tests")
		}
	}
}
