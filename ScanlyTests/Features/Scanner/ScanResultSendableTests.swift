//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

struct ScanResultSendableTests {
	@Test
	func `ScanResult survives cross-actor hand-off`() async {
		let original = ScanResult(rawContent: "hello", type: .text("hello"))

		let echoed = await Task.detached { original }.value

		#expect(echoed.rawContent == original.rawContent)
		#expect(echoed.type == original.type)
		#expect(echoed.id == original.id)
	}
}
