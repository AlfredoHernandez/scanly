//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ScannerViewModel {
	enum State: Equatable {
		case idle
		case starting
		case scanning
		case stoppingMidStart
		case failed(message: String)
	}

	private(set) var state: State = .idle
	private(set) var isDetectingCode = false
	var isTorchOn = false
	/// Bounding box of the most recently committed live-camera scan, in
	/// AVFoundation metadata-output coordinates. Set on commit and
	/// auto-cleared after `highlightDuration` so the view can flash a
	/// short overlay around the detected QR before the sheet covers it
	/// (§10.1.4). `nil` for image-picker submissions, which have no
	/// AVFoundation source to project from.
	private(set) var lastDetectionBounds: CGRect?

	/// Result-sheet presentation and history-persistence side-effect
	/// per §10.2. The VM hands accepted scans to `coordinator.present(_:)`
	/// and never touches `latestResult` or the repository directly —
	/// keeping the pipeline focused on scanner state and isolating the
	/// persistence seam to a single call-site. Module-internal so
	/// `ScannerView` can build a `Binding` against the coordinator's
	/// `latestResult` for `.sheet(item:)`.
	let coordinator: ScanResultCoordinator

	private let scanner: QRScanning
	private let torch: TorchControlling
	private let haptics: HapticFeedbackControlling
	private let sound: DetectionSoundPlaying
	private let settings: ScannerSettingsReading
	private let parser: QRContentParsing
	private let clock: @Sendable () -> Date
	private let sleeper: Sleeper
	private let highlightDuration: Duration

	@ObservationIgnored private var restartRequestedAfterStop = false
	@ObservationIgnored private var isPausedForResult = false
	@ObservationIgnored private var preservedTorchState = false
	@ObservationIgnored private var lastPresentedContent: String?
	@ObservationIgnored private var cooldown: PostDismissCooldown
	@ObservationIgnored private var highlightClearTask: Task<Void, Never>?
	/// Monotonic counter bumped on every highlight start and every
	/// cancellation. The auto-clear Task captures the generation it was
	/// spawned under; if the field has moved by the time the sleep
	/// returns (because a newer commit replaced the highlight, or
	/// `cancelDetectionHighlight()` invalidated it after the sleep
	/// already resumed), the clear is skipped.
	@ObservationIgnored private var highlightGeneration: UInt64 = 0

	var isTorchAvailable: Bool {
		torch.isTorchAvailable
	}

	/// Builds the view model with the dependencies its commit pipeline needs.
	///
	/// - Parameters:
	///   - scanner: Live-camera scan source. The VM installs its own
	///     `onScan` / `onDetectionChange` callbacks on the instance.
	///   - torch: Hardware torch driver. The VM also persists/restores
	///     torch state across the result-presentation pause cycle.
	///   - haptics: Success-haptic feedback fired once per committed scan.
	///   - sound: Optional confirmation-sound channel (§10.1.4). Only
	///     plays when `settings.isDetectionSoundEnabled` is `true`.
	///   - settings: Read-only access to scanner preferences.
	///   - clock: Time source for `ScanResult.scannedAt` and for the
	///     post-dismiss cooldown's elapsed-time check.
	///   - parser: QR content parser. Defaults to `QRContentParser()`.
	///   - sleeper: Time-suspension primitive used to auto-clear
	///     `lastDetectionBounds` after `highlightDuration`. Tests inject a
	///     `ControllableSleeper`; production uses `TaskSleeper()`.
	///   - cooldownWindow: Duration in seconds during which a re-scan of
	///     the just-dismissed `rawContent` is suppressed (§10.1.3).
	///     Defaults to 2 seconds — long enough to absorb the user lifting
	///     the camera away from a still-visible QR after dismissal, short
	///     enough that intentional re-scans aren't blocked.
	///   - highlightDuration: How long the detection-highlight bounding
	///     box stays on screen after a live commit (§10.1.4). Defaults to
	///     250 ms — brief enough to read as a flash, long enough to
	///     register before the sheet covers the preview.
	init(
		scanner: QRScanning,
		torch: TorchControlling,
		haptics: HapticFeedbackControlling,
		sound: DetectionSoundPlaying,
		settings: ScannerSettingsReading,
		coordinator: ScanResultCoordinator,
		clock: @escaping @Sendable () -> Date,
		parser: QRContentParsing = QRContentParser(),
		sleeper: Sleeper = TaskSleeper(),
		cooldownWindow: TimeInterval = 2.0,
		highlightDuration: Duration = .milliseconds(250),
	) {
		self.scanner = scanner
		self.torch = torch
		self.haptics = haptics
		self.sound = sound
		self.settings = settings
		self.coordinator = coordinator
		self.parser = parser
		self.clock = clock
		self.sleeper = sleeper
		self.highlightDuration = highlightDuration
		cooldown = PostDismissCooldown(window: cooldownWindow, clock: clock)
		// `[weak self]` breaks the closure cycle: scanner holds the closure,
		// the closure would otherwise hold self, and self holds the scanner.
		self.scanner.onScan = { [weak self] raw, format, bounds in
			self?.handleScan(raw, format: format, bounds: bounds)
		}
		self.scanner.onDetectionChange = { [weak self] detecting in
			self?.handleDetectionChange(detecting)
		}
	}

	func start() async {
		// Short-circuit while a result sheet is still presented. The
		// `.task(id: scenePhase)` modifier in `ScannerView` re-fires
		// `start()` whenever the app returns to `.active`; without this
		// guard the capture session would resume *under* an open sheet,
		// burning the camera and skipping the dismissal/cooldown cycle
		// that owns the legitimate resume path. `didDismissResult()`
		// brings the scanner back online once the user actually dismisses.
		guard coordinator.latestResult == nil else { return }
		switch state {
		case .starting, .scanning:
			return

		case .stoppingMidStart:
			restartRequestedAfterStop = true
			return

		case .idle, .failed:
			break
		}
		restartRequestedAfterStop = false
		state = .starting
		await performStart()

		if restartRequestedAfterStop, case .idle = state {
			restartRequestedAfterStop = false
			await start()
		}
	}

	private func performStart() async {
		do {
			try await scanner.start()
			finishStart(with: .success(()))
		} catch {
			finishStart(with: .failure(error))
		}
	}

	private func finishStart(with result: Result<Void, Error>) {
		if case .stoppingMidStart = state {
			state = .idle
			return
		}
		switch result {
		case .success:
			state = .scanning

		case let .failure(error as QRScannerError):
			state = .failed(message: String(localized: error.localizationKey))
			Logger.scanner.error("Scanner start failed: \(String(describing: error), privacy: .public)")

		case let .failure(error):
			state = .failed(message: error.localizedDescription)
			Logger.scanner.error("Scanner start failed: \(error.localizedDescription, privacy: .private)")
		}
	}

	/// Public stop. Halts the underlying scanner and clears most pending
	/// flags so external callers (scenePhase backgrounding, `onDisappear`)
	/// don't carry stale state forward.
	///
	/// **Exception:** when a result sheet is still presented
	/// (`latestResult != nil`), the pause-for-result intent is preserved
	/// — `isPausedForResult`, `preservedTorchState`, and
	/// `lastPresentedContent` survive. This matters because scenePhase
	/// backgrounding fires `stop()` while the sheet is up; without the
	/// preservation, the eventual dismissal in foreground would see a
	/// cleared flag and leave the scanner dead instead of resuming.
	/// `start()` ignores re-entries while a result is up, so the
	/// scanner can only come back through the dismissal path.
	func stop() {
		restartRequestedAfterStop = false
		cancelDetectionHighlight()
		if coordinator.latestResult == nil {
			isPausedForResult = false
			preservedTorchState = false
			lastPresentedContent = nil
		}
		stopSession()
	}

	/// Halts the underlying scanner and transitions state to `.idle`
	/// (or `.stoppingMidStart` if a start is in flight) **without**
	/// modifying pending operation flags. Callers that need flags
	/// cleared must do so themselves before calling this method.
	private func stopSession() {
		if case .starting = state {
			state = .stoppingMidStart
		} else {
			state = .idle
		}
		isDetectingCode = false
		scanner.stop()
	}

	func toggleTorch() {
		let desired = !isTorchOn
		do {
			try torch.setTorch(desired)
			isTorchOn = desired
			Logger.scanner.info("Torch toggled to \(desired, privacy: .public)")
		} catch {
			Logger.scanner.error("Torch toggle failed: \(error.localizedDescription, privacy: .private)")
		}
	}

	private func handleDetectionChange(_ detecting: Bool) {
		// `true` is only trusted in `.scanning`; `false` is always safe to apply.
		guard case .scanning = state else {
			if !detecting { isDetectingCode = false }
			return
		}
		isDetectingCode = detecting
	}

	/// Commits a scan from any source (live camera or image decoder). Gated
	/// only on `latestResult == nil` and non-empty content; callers with
	/// stricter preconditions (e.g. live scanning must be in `.scanning`)
	/// add their own guards before calling in.
	func submit(content: String, format: BarcodeFormat) {
		commit(content: content, format: format, bounds: nil)
	}

	private func handleScan(_ raw: String, format: BarcodeFormat, bounds: CGRect) {
		guard case .scanning = state else { return }
		commit(content: raw, format: format, bounds: bounds)
	}

	private func commit(content raw: String, format: BarcodeFormat, bounds: CGRect?) {
		guard coordinator.latestResult == nil else { return }
		let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !content.isEmpty else { return }
		guard !cooldown.shouldSuppress(content) else { return }

		let type = parser.parse(content)
		// Persisting + publishing is the coordinator's job — VM only
		// builds the value and hands it off. Save failures are logged
		// in the coordinator; the sheet still appears.
		coordinator.present(ScanResult(
			rawContent: content,
			type: type,
			format: format,
			scannedAt: clock(),
		))
		lastPresentedContent = content
		if let bounds {
			showDetectionHighlight(bounds: bounds)
		}
		// VM owns the commit guards, so the haptic fires here — single
		// source of truth for "a real scan just happened."
		haptics.playSuccess()
		if settings.isDetectionSoundEnabled {
			sound.playDetectionSound()
		}
		Logger.scanner
			.info("Scanned type=\(type.discriminator, privacy: .public) format=\(format.rawValue, privacy: .public) length=\(content.count, privacy: .public)")

		pauseSessionForResult()
	}

	private func showDetectionHighlight(bounds: CGRect) {
		highlightClearTask?.cancel()
		highlightGeneration &+= 1
		let generation = highlightGeneration
		lastDetectionBounds = bounds
		// The Task inherits MainActor isolation from the enclosing
		// method, so the body resumes on the main actor without an
		// explicit hop. The generation guard handles the narrow window
		// where `cancel()` arrives after `sleeper.sleep(for:)` has
		// already resumed — the task otherwise continues past the
		// `catch` and would erase bounds set by a newer commit.
		highlightClearTask = Task { [weak self, sleeper, highlightDuration, generation] in
			do {
				try await sleeper.sleep(for: highlightDuration)
			} catch {
				return
			}
			guard let self, generation == highlightGeneration else { return }
			lastDetectionBounds = nil
		}
	}

	private func cancelDetectionHighlight() {
		highlightClearTask?.cancel()
		highlightClearTask = nil
		highlightGeneration &+= 1
		lastDetectionBounds = nil
	}

	/// Reacts to the result sheet dismissal. The method performs two
	/// independent legs:
	///
	/// 1. **Cooldown record** — if a commit set `lastPresentedContent`,
	///    record the dismissal at the current clock time so subsequent
	///    detections of the same payload are suppressed for the
	///    cooldown window (§10.1.3). This leg runs even when the
	///    session was never paused (image-picker submit from `.idle`).
	/// 2. **Session restore** — if `pauseSessionForResult` armed the
	///    pause flag, restart the scanner and restore the torch to its
	///    pre-presentation state. Skipped when the pause was never
	///    engaged.
	///
	/// Called by the view on the `latestResult: non-nil → nil`
	/// transition. Spurious calls without a prior commit are safe:
	/// both legs short-circuit when their respective state is unset.
	func didDismissResult() async {
		if let content = lastPresentedContent {
			cooldown.recordDismissal(of: content)
			lastPresentedContent = nil
		}
		cancelDetectionHighlight()
		guard isPausedForResult else { return }
		isPausedForResult = false
		let shouldRestoreTorch = preservedTorchState
		preservedTorchState = false

		await start()

		guard shouldRestoreTorch, case .scanning = state else { return }
		do {
			try torch.setTorch(true)
			isTorchOn = true
			Logger.scanner.info("Torch restored after result dismissal")
		} catch {
			Logger.scanner.error("Torch restore failed: \(String(describing: error), privacy: .private)")
		}
	}

	private func pauseSessionForResult() {
		// Only an actively scanning session has anything to pause. From
		// `.idle` / `.starting` / `.failed` (e.g. a submit() from the
		// image-picker path before start()) the commit just shows the
		// result without touching the scanner.
		guard case .scanning = state else { return }
		if isTorchOn {
			do {
				try torch.setTorch(false)
				// Commit the torch transition only when the hardware
				// actually obeyed: otherwise the VM keeps reporting the
				// torch as on (which matches the still-on hardware), and
				// dismissal won't try to "restore" a torch that never
				// disabled.
				isTorchOn = false
				preservedTorchState = true
			} catch {
				Logger.scanner.error("Torch off during pause failed: \(String(describing: error), privacy: .private)")
			}
		}
		stopSession()
		isPausedForResult = true
	}
}
