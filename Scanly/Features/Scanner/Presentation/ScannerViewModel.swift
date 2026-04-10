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
	private let parser: QRContentParsing
	private let clock: @Sendable () -> Date

	private var restartRequestedAfterStop = false

	var isTorchAvailable: Bool {
		torch.isTorchAvailable
	}

	init(
		scanner: QRScanning,
		torch: TorchControlling,
		parser: QRContentParsing = QRContentParser(),
		clock: @escaping @Sendable () -> Date,
	) {
		self.scanner = scanner
		self.torch = torch
		self.parser = parser
		self.clock = clock
		// `[weak self]`: scanner outlives the VM via the composition root.
		self.scanner.onScan = { [weak self] raw in
			self?.handleScan(raw)
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

	func updateRegionOfInterest(_ layerRect: CGRect) {
		scanner.setRegionOfInterest(layerRect)
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

	private func handleScan(_ raw: String) {
		guard case .scanning = state else { return }
		guard latestResult == nil else { return }
		let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !content.isEmpty else { return }

		let type = parser.parse(content)
		latestResult = ScanResult(rawContent: content, type: type, scannedAt: clock())
		Logger.scanner.info("Scanned QR type=\(type.discriminator, privacy: .public) length=\(content.count, privacy: .public)")
	}
}
