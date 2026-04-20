//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

/// Compile-time canary: if a non-Sendable property is ever added to
/// `ScanResult`, `Task.detached { original }` will fail to build under
/// Swift 6 strict concurrency and this file will stop compiling. The
/// runtime assertions just confirm the detached task actually returns
/// the value unchanged — cross-actor handoff works.
struct ScanResultSendableTests {
	@Test
	func `ScanResult can be captured by a detached task`() async {
		let original = ScanResult(rawContent: "hello", type: .text("hello"), format: .qr)

		let echoed = await Task.detached { original }.value

		#expect(echoed == original)
	}
}
