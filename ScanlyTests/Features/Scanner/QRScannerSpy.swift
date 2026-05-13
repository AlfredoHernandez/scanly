//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import CoreGraphics
import Foundation

@MainActor
final class QRScannerSpy: QRScanning {
	/// Default normalized bounds used when callers don't pass an explicit
	/// rect to `simulateScan(_:format:bounds:)`. Sits roughly centered in
	/// metadata-output coordinates so view-side projection never trips on
	/// `.zero`.
	static let defaultBounds = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

	var onScan: ((String, BarcodeFormat, CGRect) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?

	private(set) var startCallCount = 0
	private(set) var stopCallCount = 0

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

	func waitForStartEntered() async {
		if startCallCount > 0 { return }
		await withCheckedContinuation { startEnteredWaiters.append($0) }
	}

	func simulateScan(_ raw: String, format: BarcodeFormat = .qr, bounds: CGRect = QRScannerSpy.defaultBounds) {
		onScan?(raw, format, bounds)
	}

	func simulateDetectionChange(_ detecting: Bool) {
		onDetectionChange?(detecting)
	}
}
