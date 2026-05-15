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
		let (sut, env) = makeSUT(rawContent: "WIFI:S:Home;T:WPA;P:secret;;")

		sut.copyRawContent()

		#expect(env.pasteboard.copiedStrings == ["WIFI:S:Home;T:WPA;P:secret;;"])
	}

	@Test
	func `copyRawContent leaves the pasteboard untouched until invoked`() {
		let (_, env) = makeSUT()

		#expect(env.pasteboard.copiedStrings.isEmpty)
	}

	// MARK: - share()

	@Test
	func `share sends the full raw payload to the share sheet`() {
		let (sut, env) = makeSUT(rawContent: "https://example.com/page")

		sut.share()

		#expect(env.sharing.sharedItems == ["https://example.com/page"])
	}

	@Test
	func `share leaves the share sheet untouched until invoked`() {
		let (_, env) = makeSUT()

		#expect(env.sharing.sharedItems.isEmpty)
	}

	// MARK: - primaryAction

	@Test
	func `primaryAction derives the per-type action from the scanned result`() throws {
		let url = try #require(URL(string: "https://example.com"))
		let (sut, _) = makeSUT(type: .url(url))

		#expect(sut.primaryAction == .openURL(url))
	}

	// MARK: - performPrimaryAction()

	@Test
	func `performPrimaryAction on a text scan shares the raw content`() {
		let (sut, env) = makeSUT(rawContent: "just some text", type: .text("just some text"))

		sut.performPrimaryAction()

		#expect(env.sharing.sharedItems == ["just some text"])
	}

	@Test
	func `performPrimaryAction on a URL scan raises the confirmation alert without opening`() throws {
		let url = try #require(URL(string: "https://example.com"))
		let (sut, env) = makeSUT(type: .url(url))

		sut.performPrimaryAction()

		#expect(sut.activeAlert == .urlConfirmation(url))
		#expect(sut.isAlertActive)
		#expect(env.urlOpener.openedURLs.isEmpty, "The URL must not open until the user confirms")
	}

	@Test
	func `performPrimaryAction on a phone scan places the call`() async throws {
		let (sut, env) = makeSUT(type: .phone("+14155551212"))

		sut.performPrimaryAction()

		try await waitUntil { env.phoneCaller.calledNumbers == ["+14155551212"] }
	}

	@Test
	func `performPrimaryAction on a location scan opens it in maps`() {
		let (sut, env) = makeSUT(type: .location(latitude: 19.4326, longitude: -99.1332))

		sut.performPrimaryAction()

		#expect(env.mapsOpener.openedCoordinates == [.init(latitude: 19.4326, longitude: -99.1332)])
	}

	// MARK: - confirmURLOpen()

	@Test
	func `confirmURLOpen opens the pending URL and clears the alert`() async throws {
		let url = try #require(URL(string: "https://example.com/page"))
		let (sut, env) = makeSUT(type: .url(url))
		sut.performPrimaryAction()

		sut.confirmURLOpen()

		#expect(sut.activeAlert == .none)
		try await waitUntil { env.urlOpener.openedURLs == [url] }
	}

	@Test
	func `confirmURLOpen is a no-op when no alert is active`() {
		let (sut, env) = makeSUT(rawContent: "just text", type: .text("just text"))

		sut.confirmURLOpen()

		#expect(env.urlOpener.openedURLs.isEmpty)
	}

	// MARK: - dismissAlert()

	@Test
	func `dismissAlert clears the alert without opening the URL`() throws {
		let url = try #require(URL(string: "https://example.com"))
		let (sut, env) = makeSUT(type: .url(url))
		sut.performPrimaryAction()

		sut.dismissAlert()

		#expect(sut.activeAlert == .none)
		#expect(env.urlOpener.openedURLs.isEmpty)
	}

	// MARK: - Helpers

	private func makeSUT(
		rawContent: String = "raw-content",
		type: QRType? = nil,
	) -> (sut: ScanResultActionsViewModel, env: Environment) {
		let pasteboard = PasteboardSpy()
		let sharing = SharingSpy()
		let urlOpener = URLOpeningSpy()
		let phoneCaller = PhoneCallPlacingSpy()
		let mapsOpener = MapsOpeningSpy()
		let viewModel = ScanResultActionsViewModel(
			result: anyResult(rawContent: rawContent, type: type),
			pasteboard: pasteboard,
			sharing: sharing,
			urlOpener: urlOpener,
			phoneCaller: phoneCaller,
			mapsOpener: mapsOpener,
		)
		return (
			viewModel,
			Environment(
				pasteboard: pasteboard,
				sharing: sharing,
				urlOpener: urlOpener,
				phoneCaller: phoneCaller,
				mapsOpener: mapsOpener,
			),
		)
	}

	/// Bundles the collaborators `makeSUT()` constructs alongside the SUT
	/// so adding a dependency to `ScanResultActionsViewModel` does not
	/// force every test site to widen a `_` tuple list — only the tests
	/// that use the new collaborator are touched.
	private struct Environment {
		let pasteboard: PasteboardSpy
		let sharing: SharingSpy
		let urlOpener: URLOpeningSpy
		let phoneCaller: PhoneCallPlacingSpy
		let mapsOpener: MapsOpeningSpy
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
