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
	var latestResult: ScanResult?
	private(set) var isDetectingCode = false
	var isTorchOn = false

	private let scanner: QRScanning
	private let torch: TorchControlling
	private let haptics: HapticFeedbackControlling
	private let parser: QRContentParsing
	private let clock: @Sendable () -> Date

	private var restartRequestedAfterStop = false

	var isTorchAvailable: Bool {
		torch.isTorchAvailable
	}

	init(
		scanner: QRScanning,
		torch: TorchControlling,
		haptics: HapticFeedbackControlling,
		clock: @escaping @Sendable () -> Date,
		parser: QRContentParsing = QRContentParser(),
	) {
		self.scanner = scanner
		self.torch = torch
		self.haptics = haptics
		self.parser = parser
		self.clock = clock
		// `[weak self]` breaks the closure cycle: scanner holds the closure,
		// the closure would otherwise hold self, and self holds the scanner.
		self.scanner.onScan = { [weak self] raw, format in
			self?.handleScan(raw, format: format)
		}
		self.scanner.onDetectionChange = { [weak self] detecting in
			self?.handleDetectionChange(detecting)
		}
	}

	func start() async {
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

	func stop() {
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
		commit(content: content, format: format)
	}

	private func handleScan(_ raw: String, format: BarcodeFormat) {
		guard case .scanning = state else { return }
		commit(content: raw, format: format)
	}

	private func commit(content raw: String, format: BarcodeFormat) {
		guard latestResult == nil else { return }
		let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !content.isEmpty else { return }

		let type = parser.parse(content)
		latestResult = ScanResult(
			rawContent: content,
			type: type,
			format: format,
			scannedAt: clock(),
		)
		// VM owns the commit guards, so the haptic fires here — single
		// source of truth for "a real scan just happened."
		haptics.playSuccess()
		Logger.scanner
			.info("Scanned type=\(type.discriminator, privacy: .public) format=\(format.rawValue, privacy: .public) length=\(content.count, privacy: .public)")
	}
}
