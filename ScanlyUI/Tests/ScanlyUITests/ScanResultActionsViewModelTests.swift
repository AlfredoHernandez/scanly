//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
@testable import ScanlyUI
import Foundation
import ScanlyEngineTestSupport
import Testing

@MainActor
struct ScanResultActionsViewModelTests {
	// MARK: - copyRawContent()

	@Test
	func `copyRawContent copies the full raw payload to the pasteboard`() {
		let (sut, pasteboard) = makeSUT(rawContent: "WIFI:S:Home;T:WPA;P:secret;;")

		sut.copyRawContent()

		#expect(pasteboard.copiedStrings == ["WIFI:S:Home;T:WPA;P:secret;;"])
	}

	@Test
	func `copyRawContent leaves the pasteboard untouched until invoked`() {
		let (_, pasteboard) = makeSUT()

		#expect(pasteboard.copiedStrings.isEmpty)
	}

	// MARK: - Helpers

	private func makeSUT(
		rawContent: String = "raw-content",
	) -> (sut: ScanResultActionsViewModel, pasteboard: PasteboardSpy) {
		let pasteboard = PasteboardSpy()
		let viewModel = ScanResultActionsViewModel(
			result: anyResult(rawContent: rawContent),
			pasteboard: pasteboard,
		)
		return (viewModel, pasteboard)
	}
}
