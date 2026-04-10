//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation

@MainActor
final class QRScannerSpy: QRScanning {
	var onScan: ((String) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?

	private(set) var startCallCount = 0
	private(set) var stopCallCount = 0
	private(set) var regionOfInterestCalls: [CGRect] = []

	var startError: Error?
	var startBlocker: (@MainActor () async -> Void)?

	private var startEnteredWaiters: [CheckedContinuation<Void, Never>] = []

	func start() async throws {
		startCallCount += 1
		let waiters = startEnteredWaiters
		startEnteredWaiters.removeAll()
		for continuation in waiters {
			continuation.resume()
		}
		if let startBlocker {
			await startBlocker()
		}
		if let startError {
			throw startError
		}
	}

	func stop() {
		stopCallCount += 1
	}

	func setRegionOfInterest(_ layerRect: CGRect) {
		regionOfInterestCalls.append(layerRect)
	}

	func waitForStartEntered() async {
		if startCallCount > 0 { return }
		await withCheckedContinuation { startEnteredWaiters.append($0) }
	}

	func simulateScan(_ raw: String) {
		onScan?(raw)
	}

	func simulateDetectionChange(_ detecting: Bool) {
		onDetectionChange?(detecting)
	}
}
