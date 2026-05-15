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
		let (sut, pasteboard, _) = makeSUT(rawContent: "WIFI:S:Home;T:WPA;P:secret;;")

		sut.copyRawContent()

		#expect(pasteboard.copiedStrings == ["WIFI:S:Home;T:WPA;P:secret;;"])
	}

	@Test
	func `copyRawContent leaves the pasteboard untouched until invoked`() {
		let (_, pasteboard, _) = makeSUT()

		#expect(pasteboard.copiedStrings.isEmpty)
	}

	// MARK: - share()

	@Test
	func `share sends the full raw payload to the share sheet`() {
		let (sut, _, sharing) = makeSUT(rawContent: "https://example.com/page")

		sut.share()

		#expect(sharing.sharedItems == ["https://example.com/page"])
	}

	@Test
	func `share leaves the share sheet untouched until invoked`() {
		let (_, _, sharing) = makeSUT()

		#expect(sharing.sharedItems.isEmpty)
	}

	// MARK: - primaryAction

	@Test
	func `primaryAction derives the per-type action from the scanned result`() throws {
		let url = try #require(URL(string: "https://example.com"))
		let (sut, _, _) = makeSUT(type: .url(url))

		#expect(sut.primaryAction == .openURL(url))
	}

	// MARK: - performPrimaryAction()

	@Test
	func `performPrimaryAction on a text scan shares the raw content`() {
		let (sut, _, sharing) = makeSUT(rawContent: "just some text", type: .text("just some text"))

		sut.performPrimaryAction()

		#expect(sharing.sharedItems == ["just some text"])
	}

	// MARK: - Helpers

	private func makeSUT(
		rawContent: String = "raw-content",
		type: QRType? = nil,
	) -> (sut: ScanResultActionsViewModel, pasteboard: PasteboardSpy, sharing: SharingSpy) {
		let pasteboard = PasteboardSpy()
		let sharing = SharingSpy()
		let viewModel = ScanResultActionsViewModel(
			result: anyResult(rawContent: rawContent, type: type),
			pasteboard: pasteboard,
			sharing: sharing,
		)
		return (viewModel, pasteboard, sharing)
	}

	// MARK: - Test doubles

	@MainActor
	private final class SharingSpy: Sharing {
		private(set) var sharedItems: [String] = []

		func share(_ text: String) {
			sharedItems.append(text)
		}
	}
}
