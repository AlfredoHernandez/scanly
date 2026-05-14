//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Observation
import OSLog
import ScanlyEngine

@MainActor
@Observable
public final class ScannerViewModel {
	public enum State: Equatable {
		case idle
		case starting
		case scanning
		case stoppingMidStart
		case failed(message: String)
	}

	public private(set) var state: State = .idle
	public private(set) var isDetectingCode = false
	public var isTorchOn = false
	/// Bounding box of the most recently committed live-camera scan in
	/// AVFoundation metadata-output coordinates. Auto-cleared after
	/// `highlightDuration`. `nil` for image-picker submissions.
	public private(set) var lastDetectionBounds: CGRect?

	public let coordinator: ScanResultCoordinator

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
	/// Bumped on every highlight start and cancellation. The auto-clear
	/// task captures the generation it was spawned under and skips the
	/// clear if a newer commit (or a cancel that lost the sleep race)
	/// has moved the field.
	@ObservationIgnored private var highlightGeneration: UInt64 = 0

	public var isTorchAvailable: Bool {
		torch.isTorchAvailable
	}

	/// - Parameters:
	///   - sleeper: Auto-clears `lastDetectionBounds`. Tests inject a
	///     `ControllableSleeper`; production uses `TaskSleeper()`.
	///   - cooldownWindow: Seconds of suppression after dismissal for the
	///     just-presented `rawContent`. Defaults to 2 s — absorbs the
	///     camera lingering on a still-visible QR.
	///   - highlightDuration: How long the detection bounding box stays
	///     on screen after a live commit. Defaults to 250 ms.
	public init(
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
		self.scanner.onScan = { [weak self] raw, format, bounds in
			self?.handleScan(raw, format: format, bounds: bounds)
		}
		self.scanner.onDetectionChange = { [weak self] detecting in
			self?.handleDetectionChange(detecting)
		}
	}

	public func start() async {
		// scenePhase → .active re-fires `start()`; without this guard the
		// capture session would resume under an open sheet. The legitimate
		// resume path goes through `didDismissResult()`.
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

	/// Halts the scanner and clears pending flags. **Exception:** while
	/// a result sheet is presented, the pause-for-result intent is
	/// preserved so scenePhase backgrounding doesn't strand the
	/// dismissal-driven resume path.
	public func stop() {
		restartRequestedAfterStop = false
		cancelDetectionHighlight()
		if coordinator.latestResult == nil {
			isPausedForResult = false
			preservedTorchState = false
			lastPresentedContent = nil
		}
		stopSession()
	}

	/// Stops the scanner and transitions state without touching pending
	/// operation flags — callers clear those themselves.
	private func stopSession() {
		if case .starting = state {
			state = .stoppingMidStart
		} else {
			state = .idle
		}
		isDetectingCode = false
		scanner.stop()
	}

	public func toggleTorch() {
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

	/// Commit from any source. Gated only on `latestResult == nil` and
	/// non-empty content; live-camera callers add the `.scanning` guard.
	public func submit(content: String, format: BarcodeFormat) {
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
		// Generation guard: a cancel that races a resumed sleep
		// would otherwise erase bounds set by a newer commit.
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

	/// Two independent legs on the sheet dismissal: record the dismissal
	/// in the cooldown (always when a commit happened, even for an
	/// image-picker submit from `.idle`), then restore the session and
	/// torch if `pauseSessionForResult` had armed them. Both legs no-op
	/// when their state is unset.
	public func didDismissResult() async {
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
		// From `.idle`/`.starting`/`.failed` (e.g. image-picker submit
		// before start) there is no session to pause.
		guard case .scanning = state else { return }
		if isTorchOn {
			do {
				try torch.setTorch(false)
				// Only commit the transition when the hardware obeyed;
				// otherwise dismissal would try to "restore" a torch
				// that never turned off.
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
