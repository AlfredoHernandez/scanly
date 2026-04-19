//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

@MainActor
struct ScannerViewModelTests {
	// MARK: - start() state transitions

	@Test
	func `start transitions to scanning on success`() async {
		let (sut, _, _, _) = makeSUT()
		await sut.start()
		#expect(sut.state == .scanning)
	}

	@Test
	func `start transitions to failed with camera unavailable message`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: QRScannerError.cameraUnavailable.localizationKey)))
	}

	@Test
	func `start transitions to failed with permission denied message`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.permissionDenied
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: QRScannerError.permissionDenied.localizationKey)))
	}

	@Test
	func `start transitions to failed with configuration failed message`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.configurationFailed
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: QRScannerError.configurationFailed.localizationKey)))
	}

	@Test
	func `start transitions to failed with torch unavailable message`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.torchUnavailable
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: QRScannerError.torchUnavailable.localizationKey)))
	}

	@Test
	func `start forwards to scanner exactly once`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		#expect(scanner.startCallCount == 1)
	}

	@Test
	func `start is a no-op when already scanning`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		await sut.start()
		#expect(scanner.startCallCount == 1, "Second start() while already scanning should not re-enter the scanner")
	}

	@Test
	func `stop during in-flight start prevents VM from lying about scanning`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let starting: Void = sut.start()
		await scanner.waitForStartEntered()

		sut.stop()
		gate.open()
		await starting

		#expect(sut.state == .idle, "VM must not flip to .scanning when stop() ran during start()")
	}

	@Test
	func `start requested during stoppingMidStart re-enters once idle`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let firstStart: Void = sut.start()
		await scanner.waitForStartEntered()

		sut.stop()
		async let secondStart: Void = sut.start()

		gate.open()
		_ = await (firstStart, secondStart)

		#expect(sut.state == .scanning, "Second start() requested during .stoppingMidStart must eventually land in .scanning")
		#expect(scanner.startCallCount == 2, "scanner.start() should be called a second time for the queued restart")
	}

	@Test
	func `stop during in-flight start that later throws lands in idle, not failed`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }
		scanner.startError = QRScannerError.cameraUnavailable

		async let starting: Void = sut.start()
		await scanner.waitForStartEntered()

		sut.stop()
		gate.open()
		await starting

		#expect(sut.state == .idle, "stop() during a start() that will throw must still land in .idle")
	}

	@Test
	func `concurrent start() calls during the in-flight window forward exactly once`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let first: Void = sut.start()
		await scanner.waitForStartEntered()
		async let second: Void = sut.start()

		gate.open()
		_ = await (first, second)

		#expect(scanner.startCallCount == 1, "Overlapping start() during the in-flight window should not forward twice")
		#expect(sut.state == .scanning)
	}

	@Test
	func `start can recover after a previous failure`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: QRScannerError.cameraUnavailable.localizationKey)))

		scanner.startError = nil
		await sut.start()
		#expect(sut.state == .scanning)
		#expect(scanner.startCallCount == 2)
	}

	// MARK: - stop()

	@Test
	func `stop forwards to scanner and resets state to idle`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		sut.stop()
		#expect(sut.state == .idle)
		#expect(scanner.stopCallCount == 1)
	}

	// MARK: - Scan handling

	@Test
	func `handling a scan produces a ScanResult with parsed type`() async throws {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		let result = try #require(sut.latestResult)
		#expect(result.rawContent == "https://example.com")
		guard case .url = result.type else {
			Issue.record("Expected .url, got \(result.type)")
			return
		}
	}

	@Test
	func `scan records the barcode format on the result`() async throws {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("1234567890128", format: .ean13)
		let result = try #require(sut.latestResult)
		#expect(result.format == .ean13)
	}

	@Test
	func `scan records scannedAt from the injected clock`() async throws {
		let fixed = Date(timeIntervalSince1970: 1_234_567_890)
		let (sut, scanner, _, _) = makeSUT(clock: { fixed })
		await sut.start()
		scanner.simulateScan("https://example.com")
		let result = try #require(sut.latestResult)
		#expect(result.scannedAt == fixed)
	}

	@Test
	func `empty payload is ignored`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `whitespace-only payload is ignored`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("   \n\t  ")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `scan arriving after stop is ignored`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		sut.stop()
		scanner.simulateScan("https://example.com")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `scan arriving during stoppingMidStart is ignored`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let starting: Void = sut.start()
		await scanner.waitForStartEntered()
		sut.stop()

		scanner.simulateScan("https://example.com")
		#expect(sut.latestResult == nil)

		gate.open()
		await starting
	}

	@Test
	func `latestResult can be cleared by the view via the @Bindable setter`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("hello")
		#expect(sut.latestResult != nil)
		sut.latestResult = nil
		#expect(sut.latestResult == nil)
	}

	// MARK: - Scan gating

	@Test
	func `scan is ignored while a result is pending`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		let first = sut.latestResult
		scanner.simulateScan("https://other.com")

		#expect(sut.latestResult?.id == first?.id, "New scans must not clobber a pending result")
		#expect(sut.latestResult?.rawContent == "https://example.com")
	}

	@Test
	func `held-in-frame same QR is suppressed until dismissal`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		let firstID = sut.latestResult?.id
		for _ in 0 ..< 20 {
			scanner.simulateScan("https://example.com")
		}

		#expect(sut.latestResult?.id == firstID, "Held-in-frame duplicates must not reset the pending result")
	}

	@Test
	func `same QR is rescanned immediately after dismissal`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		let firstID = sut.latestResult?.id
		sut.latestResult = nil

		scanner.simulateScan("https://example.com")

		#expect(sut.latestResult != nil)
		#expect(sut.latestResult?.id != firstID, "A new ScanResult should be produced after dismissal")
	}

	@Test
	func `different QR accepted after dismissal`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		sut.latestResult = nil
		scanner.simulateScan("https://other.com")

		#expect(sut.latestResult?.rawContent == "https://other.com")
	}

	// MARK: - Image submission

	@Test
	func `submit commits an external scan when idle`() {
		let (sut, _, _, _) = makeSUT()
		sut.submit(content: "https://example.com", format: .qr)
		#expect(sut.latestResult?.rawContent == "https://example.com")
		#expect(sut.latestResult?.format == .qr)
	}

	@Test
	func `submit uses the provided format on the result`() {
		let (sut, _, _, _) = makeSUT()
		sut.submit(content: "1234567890128", format: .ean13)
		#expect(sut.latestResult?.format == .ean13)
	}

	@Test
	func `submit is ignored when a result is already pending`() {
		let (sut, _, _, _) = makeSUT()
		sut.submit(content: "https://first.com", format: .qr)
		sut.submit(content: "https://second.com", format: .qr)
		#expect(sut.latestResult?.rawContent == "https://first.com")
	}

	@Test
	func `submit with empty content is ignored`() {
		let (sut, _, _, _) = makeSUT()
		sut.submit(content: "   \n\t  ", format: .qr)
		#expect(sut.latestResult == nil)
	}

	@Test
	func `submit plays haptic on committed result`() {
		let (sut, _, _, haptics) = makeSUT()
		sut.submit(content: "hello", format: .qr)
		#expect(haptics.playSuccessCallCount == 1)
	}

	// MARK: - Haptic feedback

	@Test
	func `successful scan plays haptic success feedback`() async {
		let (sut, scanner, _, haptics) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 1)
	}

	@Test
	func `scan blocked by empty payload does not play haptic`() async {
		let (sut, scanner, _, haptics) = makeSUT()
		await sut.start()
		scanner.simulateScan("")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked by whitespace-only payload does not play haptic`() async {
		let (sut, scanner, _, haptics) = makeSUT()
		await sut.start()
		scanner.simulateScan("   \n\t  ")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked while not scanning does not play haptic`() {
		let (sut, scanner, _, haptics) = makeSUT()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked by pending result does not re-play haptic`() async {
		let (sut, scanner, _, haptics) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		scanner.simulateScan("https://other.com")
		#expect(haptics.playSuccessCallCount == 1)
	}

	@Test
	func `scan in failed state does not play haptic`() async {
		let (sut, scanner, _, haptics) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 0)
	}

	// MARK: - Detection state

	@Test
	func `isDetectingCode is false by default`() {
		let (sut, _, _, _) = makeSUT()
		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection change callback flips isDetectingCode while scanning`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()

		scanner.simulateDetectionChange(true)
		#expect(sut.isDetectingCode == true)

		scanner.simulateDetectionChange(false)
		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection true is ignored when not scanning`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		sut.stop()

		scanner.simulateDetectionChange(true)

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection false is always applied even outside scanning`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateDetectionChange(true)
		#expect(sut.isDetectingCode == true)

		sut.stop()
		scanner.simulateDetectionChange(false)

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `stop resets isDetectingCode`() async {
		let (sut, scanner, _, _) = makeSUT()
		await sut.start()
		scanner.simulateDetectionChange(true)

		sut.stop()

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection true during starting is dropped`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let starting: Void = sut.start()
		await scanner.waitForStartEntered()

		scanner.simulateDetectionChange(true)
		#expect(sut.isDetectingCode == false)

		gate.open()
		await starting
	}

	@Test
	func `detection false during starting is applied`() async {
		let (sut, scanner, _, _) = makeSUT()
		let gate = OneShotMainActorGate()
		scanner.startBlocker = { await gate.wait() }

		async let starting: Void = sut.start()
		await scanner.waitForStartEntered()

		scanner.simulateDetectionChange(false)
		#expect(sut.isDetectingCode == false)

		gate.open()
		await starting
	}

	@Test
	func `detection true after failed start is dropped`() async {
		let (sut, scanner, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()

		scanner.simulateDetectionChange(true)

		#expect(sut.isDetectingCode == false)
	}

	// MARK: - Torch

	@Test
	func `toggleTorch flips isTorchOn on success`() {
		let (sut, _, _, _) = makeSUT()
		#expect(sut.isTorchOn == false)
		sut.toggleTorch()
		#expect(sut.isTorchOn == true)
		sut.toggleTorch()
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `toggleTorch does not flip isTorchOn when torch throws on enable`() {
		let (sut, _, torch, _) = makeSUT()
		torch.torchError = QRScannerError.torchUnavailable
		sut.toggleTorch()
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `toggleTorch does not flip isTorchOn when torch throws on disable`() {
		let (sut, _, torch, _) = makeSUT()
		sut.toggleTorch()
		#expect(sut.isTorchOn == true)

		torch.torchError = QRScannerError.torchUnavailable
		sut.toggleTorch()
		#expect(sut.isTorchOn == true, "Torch state must not flip when the disable call throws")
	}

	@Test
	func `isTorchAvailable reflects torch dependency`() {
		let (sut, _, torch, _) = makeSUT()
		torch.isTorchAvailable = false
		#expect(sut.isTorchAvailable == false)
	}

	// MARK: - Helpers

	private func makeSUT(
		clock: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
	) -> (sut: ScannerViewModel, scanner: QRScannerSpy, torch: TorchSpy, haptics: HapticFeedbackSpy) {
		let scanner = QRScannerSpy()
		let torch = TorchSpy()
		let haptics = HapticFeedbackSpy()
		let sut = ScannerViewModel(
			scanner: scanner,
			torch: torch,
			haptics: haptics,
			clock: clock,
		)
		return (sut, scanner, torch, haptics)
	}
}

@MainActor
private final class OneShotMainActorGate {
	private var isOpen = false
	private var waiters: [CheckedContinuation<Void, Never>] = []

	func wait() async {
		if isOpen { return }
		await withCheckedContinuation { waiters.append($0) }
	}

	func open() {
		isOpen = true
		let pending = waiters
		waiters.removeAll()
		for continuation in pending {
			continuation.resume()
		}
	}
}
