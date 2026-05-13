//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import CoreGraphics
import Foundation
import Testing

@MainActor
struct ScannerViewModelTests {
	// MARK: - start() state transitions

	@Test
	func `start transitions to scanning on success`() async {
		let (sut, _, _, _, _, _) = makeSUT()
		await sut.start()
		#expect(sut.state == .scanning)
	}

	@Test(arguments: [
		QRScannerError.cameraUnavailable,
		QRScannerError.permissionDenied,
		QRScannerError.configurationFailed,
		QRScannerError.torchUnavailable,
	])
	func `start transitions to failed with the error's localized message`(error: QRScannerError) async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		scanner.startError = error
		await sut.start()
		#expect(sut.state == .failed(message: String(localized: error.localizationKey)))
	}

	@Test
	func `start forwards to scanner exactly once`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		#expect(scanner.startCallCount == 1)
	}

	@Test
	func `start is a no-op when already scanning`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		await sut.start()
		#expect(scanner.startCallCount == 1, "Second start() while already scanning should not re-enter the scanner")
	}

	@Test
	func `stop during in-flight start prevents VM from lying about scanning`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		sut.stop()
		#expect(sut.state == .idle)
		#expect(scanner.stopCallCount == 1)
	}

	// MARK: - Scan handling

	@Test
	func `handling a scan produces a ScanResult with parsed type`() async throws {
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("1234567890128", format: .ean13)
		let result = try #require(sut.latestResult)
		#expect(result.format == .ean13)
	}

	@Test
	func `scan records scannedAt from the injected clock`() async throws {
		let fixed = Date(timeIntervalSince1970: 1_234_567_890)
		let (sut, scanner, _, _, _, _) = makeSUT(clock: { fixed })
		await sut.start()
		scanner.simulateScan("https://example.com")
		let result = try #require(sut.latestResult)
		#expect(result.scannedAt == fixed)
	}

	@Test
	func `empty payload is ignored`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `whitespace-only payload is ignored`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("   \n\t  ")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `scan arriving after stop is ignored`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		sut.stop()
		scanner.simulateScan("https://example.com")
		#expect(sut.latestResult == nil)
	}

	@Test
	func `scan arriving during stoppingMidStart is ignored`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("hello")
		#expect(sut.latestResult != nil)
		sut.latestResult = nil
		#expect(sut.latestResult == nil)
	}

	// MARK: - Scan gating

	@Test
	func `scan is ignored while a result is pending`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		let first = sut.latestResult
		scanner.simulateScan("https://other.com")

		#expect(sut.latestResult?.id == first?.id, "New scans must not clobber a pending result")
		#expect(sut.latestResult?.rawContent == "https://example.com")
	}

	@Test
	func `held-in-frame same QR is suppressed until dismissal`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")
		let firstID = sut.latestResult?.id
		for _ in 0 ..< 20 {
			scanner.simulateScan("https://example.com")
		}

		#expect(sut.latestResult?.id == firstID, "Held-in-frame duplicates must not reset the pending result")
	}

	// Same-content and different-content rescan-after-dismissal are now
	// covered explicitly by the post-dismiss cooldown tests in the
	// `Post-dismiss cooldown (§10.1.3)` section below, with clock control
	// to position the second scan inside or outside the window.

	// MARK: - Image submission

	@Test
	func `submit commits an external scan when idle`() {
		let (sut, _, _, _, _, _) = makeSUT()
		sut.submit(content: "https://example.com", format: .qr)
		#expect(sut.latestResult?.rawContent == "https://example.com")
		#expect(sut.latestResult?.format == .qr)
	}

	@Test
	func `submit uses the provided format on the result`() {
		let (sut, _, _, _, _, _) = makeSUT()
		sut.submit(content: "1234567890128", format: .ean13)
		#expect(sut.latestResult?.format == .ean13)
	}

	@Test
	func `submit is ignored when a result is already pending`() {
		let (sut, _, _, _, _, _) = makeSUT()
		sut.submit(content: "https://first.com", format: .qr)
		sut.submit(content: "https://second.com", format: .qr)
		#expect(sut.latestResult?.rawContent == "https://first.com")
	}

	@Test
	func `submit with empty content is ignored`() {
		let (sut, _, _, _, _, _) = makeSUT()
		sut.submit(content: "   \n\t  ", format: .qr)
		#expect(sut.latestResult == nil)
	}

	@Test
	func `submit plays haptic on committed result`() {
		let (sut, _, _, haptics, _, _) = makeSUT()
		sut.submit(content: "hello", format: .qr)
		#expect(haptics.playSuccessCallCount == 1)
	}

	@Test
	func `submit commits during .scanning and pauses the session`() async {
		let (sut, _, _, _, _, _) = makeSUT()
		await sut.start()
		#expect(sut.state == .scanning)

		sut.submit(content: "https://from.image", format: .qr)

		#expect(sut.latestResult?.rawContent == "https://from.image")
		#expect(sut.state == .idle, "Commit pauses the session so the result sheet has exclusive use of the screen")
	}

	// MARK: - Haptic feedback

	@Test
	func `successful scan plays haptic success feedback`() async {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 1)
	}

	@Test
	func `scan blocked by empty payload does not play haptic`() async {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked by whitespace-only payload does not play haptic`() async {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("   \n\t  ")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked while not scanning does not play haptic`() {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 0)
	}

	@Test
	func `scan blocked by pending result does not re-play haptic`() async {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		scanner.simulateScan("https://other.com")
		#expect(haptics.playSuccessCallCount == 1)
	}

	@Test
	func `scan in failed state does not play haptic`() async {
		let (sut, scanner, _, haptics, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(haptics.playSuccessCallCount == 0)
	}

	// MARK: - Detection state

	@Test
	func `isDetectingCode is false by default`() {
		let (sut, _, _, _, _, _) = makeSUT()
		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection change callback flips isDetectingCode while scanning`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()

		scanner.simulateDetectionChange(true)
		#expect(sut.isDetectingCode == true)

		scanner.simulateDetectionChange(false)
		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection true is ignored when not scanning`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		sut.stop()

		scanner.simulateDetectionChange(true)

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection false is always applied even outside scanning`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateDetectionChange(true)
		#expect(sut.isDetectingCode == true)

		sut.stop()
		scanner.simulateDetectionChange(false)

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `stop resets isDetectingCode`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateDetectionChange(true)

		sut.stop()

		#expect(sut.isDetectingCode == false)
	}

	@Test
	func `detection true during starting is dropped`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
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
		let (sut, scanner, _, _, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()

		scanner.simulateDetectionChange(true)

		#expect(sut.isDetectingCode == false)
	}

	// MARK: - Torch

	@Test
	func `toggleTorch flips isTorchOn on success`() {
		let (sut, _, _, _, _, _) = makeSUT()
		#expect(sut.isTorchOn == false)
		sut.toggleTorch()
		#expect(sut.isTorchOn == true)
		sut.toggleTorch()
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `toggleTorch does not flip isTorchOn when torch throws on enable`() {
		let (sut, _, torch, _, _, _) = makeSUT()
		torch.torchError = QRScannerError.torchUnavailable
		sut.toggleTorch()
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `toggleTorch does not flip isTorchOn when torch throws on disable`() {
		let (sut, _, torch, _, _, _) = makeSUT()
		sut.toggleTorch()
		#expect(sut.isTorchOn == true)

		torch.torchError = QRScannerError.torchUnavailable
		sut.toggleTorch()
		#expect(sut.isTorchOn == true, "Torch state must not flip when the disable call throws")
	}

	@Test
	func `isTorchAvailable reflects torch dependency`() {
		let (sut, _, torch, _, _, _) = makeSUT()
		torch.isTorchAvailable = false
		#expect(sut.isTorchAvailable == false)
	}

	@Test
	func `toggleTorch works in .idle before any start`() {
		let (sut, _, _, _, _, _) = makeSUT()
		#expect(sut.state == .idle)
		sut.toggleTorch()
		#expect(sut.isTorchOn == true, "Torch is a device-level control and should not require an active session")
	}

	@Test
	func `toggleTorch works in .failed state`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		scanner.startError = QRScannerError.cameraUnavailable
		await sut.start()
		guard case .failed = sut.state else {
			Issue.record("Expected .failed, got \(sut.state)")
			return
		}

		sut.toggleTorch()

		#expect(sut.isTorchOn == true)
	}

	// MARK: - Result presentation pauses the session (§10.1.2)

	@Test
	func `commit pauses the scanner so the session releases the camera`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")

		#expect(scanner.stopCallCount == 1, "Commit must stop the scanner to free the AVCaptureSession while the sheet is up")
		#expect(sut.state == .idle, "VM state reflects the paused session")
	}

	@Test
	func `commit with torch off does not touch torch hardware`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		let priorCallCount = torch.calls.count

		scanner.simulateScan("https://example.com")

		#expect(torch.calls.count == priorCallCount, "Torch hardware must not be touched when the torch was already off")
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `commit with torch on turns torch off during pause`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		sut.toggleTorch()
		#expect(sut.isTorchOn == true)

		scanner.simulateScan("https://example.com")

		#expect(torch.calls.last == false, "Torch hardware must be disabled before the session stops")
		#expect(sut.isTorchOn == false, "Torch indicator must reflect the disabled hardware while paused")
	}

	@Test
	func `commit swallows torch-off failure so the session still pauses`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		sut.toggleTorch()
		torch.torchError = QRScannerError.torchUnavailable

		scanner.simulateScan("https://example.com")

		#expect(scanner.stopCallCount == 1, "Session must pause even if the pre-pause torch-off call throws")
	}

	// MARK: - didDismissResult restores the session (§10.1.2)

	@Test
	func `didDismissResult restarts the scanner`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(scanner.startCallCount == 1)

		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(scanner.startCallCount == 2, "Dismissal must re-enter the scanner so live detection resumes")
		#expect(sut.state == .scanning)
	}

	@Test
	func `didDismissResult restores torch when it was on before presentation`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		sut.toggleTorch()
		scanner.simulateScan("https://example.com")
		#expect(sut.isTorchOn == false, "Torch is forced off while paused")

		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(sut.isTorchOn == true, "Torch must be restored to its pre-presentation state")
		#expect(torch.calls.last == true)
	}

	@Test
	func `didDismissResult leaves torch off when it was off before presentation`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		let priorCallCount = torch.calls.count

		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(sut.isTorchOn == false)
		#expect(torch.calls.count == priorCallCount, "Torch hardware must not be touched when the torch was off pre-pause")
	}

	@Test
	func `didDismissResult is a no-op when the VM was not paused for a result`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		let startCallsBefore = scanner.startCallCount

		await sut.didDismissResult()

		#expect(scanner.startCallCount == startCallsBefore, "Spurious dismissal must not retrigger the scanner")
		#expect(sut.state == .scanning)
	}

	@Test
	func `didDismissResult skips torch restoration when the restart fails`() async {
		let (sut, scanner, torch, _, _, _) = makeSUT()
		await sut.start()
		sut.toggleTorch()
		scanner.simulateScan("https://example.com")
		let callsAfterPause = torch.calls.count

		scanner.startError = QRScannerError.cameraUnavailable
		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(sut.isTorchOn == false, "Torch must not be re-enabled when the restart failed")
		#expect(torch.calls.count == callsAfterPause, "Torch hardware must not be re-enabled when the restart failed")
	}

	@Test
	func `external stop clears the pause flag so a later dismissal is a no-op`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		// Simulate scene phase backgrounding the app while the sheet is visible.
		sut.stop()
		let startCallsBefore = scanner.startCallCount

		await sut.didDismissResult()

		#expect(scanner.startCallCount == startCallsBefore, "Dismissal after an external stop must not retrigger the scanner")
		#expect(sut.state == .idle, "VM must stay idle after an external stop, not silently restart on dismissal")
	}

	@Test
	func `commit from non-scanning state does not stop the scanner`() {
		let (sut, scanner, _, _, _, _) = makeSUT()
		// VM stays in .idle: image-picker path can submit before start().
		sut.submit(content: "https://from.image", format: .qr)

		#expect(sut.latestResult?.rawContent == "https://from.image")
		#expect(scanner.stopCallCount == 0, "There is nothing to pause when the session is not scanning")
	}

	@Test
	func `didDismissResult after a submit during scanning lands in failed when restart throws`() async {
		// submit() reaches commit() from .scanning, so the session IS paused
		// and didDismissResult does try to restart. Mirrors the camera-path
		// "restart fails" test but the originating event was an image submit.
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		sut.submit(content: "https://from.image", format: .qr)

		scanner.startError = QRScannerError.cameraUnavailable
		sut.latestResult = nil
		await sut.didDismissResult()

		guard case .failed = sut.state else {
			Issue.record("Expected .failed after a restart that throws, got \(sut.state)")
			return
		}
		#expect(sut.isTorchOn == false)
	}

	@Test
	func `didDismissResult after an image-picker submit from idle is a no-op`() async {
		// True image-picker path: submit() fires from .idle (no prior start),
		// so commit's pause guard early-returns and isPausedForResult stays
		// false. The dismissal must not start the scanner.
		let (sut, scanner, _, _, _, _) = makeSUT()
		sut.submit(content: "https://from.image", format: .qr)
		#expect(sut.state == .idle)

		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(scanner.startCallCount == 0, "Dismissal must not start a scanner that was never paused")
		#expect(sut.state == .idle, "VM must stay idle when the image-picker submit never engaged the live session")
	}

	// MARK: - Post-dismiss cooldown (§10.1.3)

	@Test
	func `same content within the cooldown window is suppressed`() async {
		let clock = TestClock()
		let (sut, scanner, _, haptics, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com")
		let priorStops = scanner.stopCallCount
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 1.0)
		scanner.simulateScan("https://example.com")

		#expect(sut.latestResult == nil, "Cooldown must drop the duplicate detection silently")
		#expect(haptics.playSuccessCallCount == 1, "Suppressed scans must not play a second haptic")
		#expect(scanner.stopCallCount == priorStops, "Suppressed scans must not re-pause the session")
	}

	@Test
	func `different content within the cooldown window is accepted`() async {
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com")
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 1.0)
		scanner.simulateScan("https://other.com")

		#expect(sut.latestResult?.rawContent == "https://other.com")
	}

	@Test
	func `same content after the cooldown window expires is accepted`() async {
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com")
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 2.5)
		scanner.simulateScan("https://example.com")

		#expect(sut.latestResult?.rawContent == "https://example.com")
	}

	@Test
	func `submit is suppressed when same content was just live-scanned and cooldown is active`() async {
		// Per §10.1.3 the cooldown is keyed by rawContent regardless of source.
		// A gallery scan of the just-dismissed content is suppressed too.
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com")
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 1.0)
		sut.submit(content: "https://example.com", format: .qr)

		#expect(sut.latestResult == nil, "Image-picker submissions of the just-dismissed content are suppressed too")
	}

	@Test
	func `cooldown is recorded even when the session was never paused`() async {
		// Image-picker submit from .idle does not engage pauseSessionForResult,
		// but the dismissal must still record the cooldown so a subsequent
		// duplicate scan is suppressed.
		let clock = TestClock()
		let (sut, _, _, _, _, _) = makeSUT(clock: clock.now)
		sut.submit(content: "https://from.image", format: .qr)
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 1.0)
		sut.submit(content: "https://from.image", format: .qr)

		#expect(sut.latestResult == nil, "Cooldown must apply even when the originating commit never paused the session")
	}

	@Test
	func `first scan after start is never suppressed by the cooldown`() async {
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()

		scanner.simulateScan("https://example.com")

		#expect(sut.latestResult?.rawContent == "https://example.com", "Initial cooldown state must allow everything through")
	}

	@Test
	func `stop before dismissal clears the cooldown record so later scans are not suppressed`() async {
		// Models scenePhase backgrounding while the sheet is still visible:
		// stop() fires, the sheet dismisses, didDismissResult() runs — but
		// the cooldown must not record the stale content from a session the
		// system already suspended.
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com")
		sut.stop()
		// Simulate the view binding clearing latestResult, then calling the
		// dismissal hook — the same two steps SwiftUI performs when the
		// sheet binding goes nil and the .onChange handler fires.
		sut.latestResult = nil
		await sut.didDismissResult()

		await sut.start()
		clock.advance(by: 0.5)
		scanner.simulateScan("https://example.com")

		#expect(sut.latestResult?.rawContent == "https://example.com", "After an explicit stop the cooldown must not block a fresh scan of the same content")
	}

	// MARK: - Visual detection highlight (§10.1.4)

	@Test
	func `commit captures the detection bounds from a live scan`() async {
		let bounds = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com", bounds: bounds)

		#expect(sut.lastDetectionBounds == bounds, "Bounds must surface to the view for highlight rendering")
	}

	@Test
	func `image-picker submit leaves detection bounds nil`() async {
		// Gallery scans have no AVFoundation metadata, so the highlight
		// is intentionally skipped — there is nothing to draw over.
		let (sut, _, _, _, _, _) = makeSUT()
		await sut.start()

		sut.submit(content: "https://from.image", format: .qr)

		#expect(sut.lastDetectionBounds == nil, "submit() has no AVFoundation source and must not surface a stale bounds")
	}

	@Test
	func `cooldown-suppressed scan does not update detection bounds`() async {
		let clock = TestClock()
		let (sut, scanner, _, _, _, _) = makeSUT(clock: clock.now)
		await sut.start()
		scanner.simulateScan("https://example.com", bounds: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
		sut.latestResult = nil
		await sut.didDismissResult()

		clock.advance(by: 1.0)
		scanner.simulateScan("https://example.com", bounds: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3))

		#expect(sut.lastDetectionBounds == nil, "A scan dropped by the cooldown must not refresh the highlight bounds")
	}

	@Test
	func `detection bounds auto-clear after the highlight duration`() async throws {
		let sleeper = ControllableSleeper()
		let (sut, scanner, _, _, _, _) = makeSUT(sleeper: sleeper)
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(sut.lastDetectionBounds != nil)

		try await sleeper.waitForSleep()
		sleeper.resumeAll()
		// `resumeAll` schedules the auto-clear task to continue but does
		// not block until it runs. Yield until the side effect lands or a
		// generous retry budget is exhausted; 10 yields is far more than
		// enough for a single MainActor-isolated task to be drained.
		for _ in 0 ..< 10 where sut.lastDetectionBounds != nil {
			await Task.yield()
		}

		#expect(sut.lastDetectionBounds == nil, "Bounds must clear automatically once the highlight duration elapses")
	}

	@Test
	func `stop immediately after commit clears bounds synchronously`() async {
		// Models a scenePhase background firing in the same runloop turn
		// as the scan callback: the highlight task has been spawned but
		// hasn't yet reached the sleeper. stop() must zero the bounds
		// without waiting for the sleeper to be released.
		let sleeper = ControllableSleeper()
		let (sut, scanner, _, _, _, _) = makeSUT(sleeper: sleeper)
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(sut.lastDetectionBounds != nil)

		sut.stop()

		#expect(sut.lastDetectionBounds == nil, "stop() must clear the highlight synchronously, before the sleeper ever resumes")
		#expect(sleeper.waiterCount <= 1, "Cancellation is in flight; remaining waiter count must not grow")
	}

	@Test
	func `didDismissResult clears detection bounds`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(sut.lastDetectionBounds != nil)

		sut.latestResult = nil
		await sut.didDismissResult()

		#expect(sut.lastDetectionBounds == nil, "Dismissal must wipe the highlight so a re-presentation starts clean")
	}

	@Test
	func `stop clears detection bounds`() async {
		let (sut, scanner, _, _, _, _) = makeSUT()
		await sut.start()
		scanner.simulateScan("https://example.com")
		#expect(sut.lastDetectionBounds != nil)

		sut.stop()

		#expect(sut.lastDetectionBounds == nil, "External stop must drop any in-flight highlight")
	}

	// MARK: - Detection confirmation sound (§10.1.4)

	@Test
	func `detection sound plays on commit when the setting is enabled`() async {
		let settings = ScannerSettingsStub(isDetectionSoundEnabled: true)
		let (sut, scanner, _, _, sound, _) = makeSUT(settings: settings)
		await sut.start()

		scanner.simulateScan("https://example.com")

		#expect(sound.playDetectionSoundCallCount == 1)
	}

	@Test
	func `detection sound is silent when the setting is disabled`() async {
		// Default settings: isDetectionSoundEnabled == false (opt-in per §10.1.4).
		let (sut, scanner, _, _, sound, _) = makeSUT()
		await sut.start()

		scanner.simulateScan("https://example.com")

		#expect(sound.playDetectionSoundCallCount == 0, "Sound is opt-in; default disabled state must produce silence")
	}

	@Test
	func `image-picker submit plays sound when the setting is enabled`() async {
		let settings = ScannerSettingsStub(isDetectionSoundEnabled: true)
		let (sut, _, _, _, sound, _) = makeSUT(settings: settings)
		await sut.start()

		sut.submit(content: "https://from.image", format: .qr)

		#expect(sound.playDetectionSoundCallCount == 1, "Gallery scans are full scan events too — they fire the sound when enabled")
	}

	@Test
	func `cooldown-suppressed scan does not play sound`() async {
		let clock = TestClock()
		let settings = ScannerSettingsStub(isDetectionSoundEnabled: true)
		let (sut, scanner, _, _, sound, _) = makeSUT(clock: clock.now, settings: settings)
		await sut.start()
		scanner.simulateScan("https://example.com")
		sut.latestResult = nil
		await sut.didDismissResult()
		let priorCount = sound.playDetectionSoundCallCount

		clock.advance(by: 1.0)
		scanner.simulateScan("https://example.com")

		#expect(sound.playDetectionSoundCallCount == priorCount, "Suppressed re-scans must not fire feedback")
	}

	@Test
	func `empty payload does not play sound even when enabled`() async {
		let settings = ScannerSettingsStub(isDetectionSoundEnabled: true)
		let (sut, scanner, _, _, sound, _) = makeSUT(settings: settings)
		await sut.start()

		scanner.simulateScan("")

		#expect(sound.playDetectionSoundCallCount == 0)
	}

	@Test
	func `scan while a result is pending does not play sound twice`() async {
		let settings = ScannerSettingsStub(isDetectionSoundEnabled: true)
		let (sut, scanner, _, _, sound, _) = makeSUT(settings: settings)
		await sut.start()
		scanner.simulateScan("https://example.com")
		scanner.simulateScan("https://other.com")

		#expect(sound.playDetectionSoundCallCount == 1, "Second scan blocked by latestResult guard must not re-play sound")
	}

	// MARK: - Helpers

	private func makeSUT(
		clock: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
		sleeper: Sleeper? = nil,
		cooldownWindow: TimeInterval = 2.0,
		highlightDuration: Duration = .milliseconds(250),
		settings: ScannerSettingsStub = ScannerSettingsStub(),
	) -> (
		sut: ScannerViewModel,
		scanner: QRScannerSpy,
		torch: TorchSpy,
		haptics: HapticFeedbackSpy,
		sound: DetectionSoundPlayingSpy,
		settings: ScannerSettingsStub,
	) {
		let scanner = QRScannerSpy()
		let torch = TorchSpy()
		let haptics = HapticFeedbackSpy()
		let sound = DetectionSoundPlayingSpy()
		// Default to a `ControllableSleeper` so commit-spawned highlight
		// tasks never escape the test as live 250ms waits. Tests that
		// observe the auto-clear pass their own sleeper and release it
		// explicitly via `resumeAll()`.
		let resolvedSleeper = sleeper ?? ControllableSleeper()
		let sut = ScannerViewModel(
			scanner: scanner,
			torch: torch,
			haptics: haptics,
			sound: sound,
			settings: settings,
			clock: clock,
			sleeper: resolvedSleeper,
			cooldownWindow: cooldownWindow,
			highlightDuration: highlightDuration,
		)
		return (sut, scanner, torch, haptics, sound, settings)
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
