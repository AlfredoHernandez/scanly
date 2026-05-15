//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Testing

/// Reserved for app-target integration tests (composition root,
/// SwiftUI integration, scenePhase wiring) that need `@testable
/// import Scanly`. Unit-test logic for ScanlyEngine and ScanlyUI
/// lives in those packages' own test bundles.
@Test
func `scanly app target compiles`() {
	#expect(Bool(true))
}
