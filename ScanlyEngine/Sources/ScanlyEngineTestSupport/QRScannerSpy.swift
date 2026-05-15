//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import CoreGraphics
import Foundation
import ScanlyEngine

@MainActor
public final class QRScannerSpy: QRScanning {
	/// Default normalized bounds used when callers don't pass an explicit
	/// rect to `simulateScan(_:format:bounds:)`. Sits roughly centered in
	/// metadata-output coordinates so view-side projection never trips on
	/// `.zero`.
	public static let defaultBounds = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)

	public var onScan: ((String, BarcodeFormat, CGRect) -> Void)?
	public var onDetectionChange: ((Bool) -> Void)?

	public private(set) var startCallCount = 0
	public private(set) var stopCallCount = 0

	public var startError: Error?
	public var startBlocker: (@MainActor () async -> Void)?

	private var startEnteredWaiters: [CheckedContinuation<Void, Never>] = []

	public init() {}

	public func start() async throws {
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

	public func stop() {
		stopCallCount += 1
	}

	public func waitForStartEntered() async {
		if startCallCount > 0 { return }
		await withCheckedContinuation { startEnteredWaiters.append($0) }
	}

	public func simulateScan(_ raw: String, format: BarcodeFormat = .qr, bounds: CGRect = QRScannerSpy.defaultBounds) {
		onScan?(raw, format, bounds)
	}

	public func simulateDetectionChange(_ detecting: Bool) {
		onDetectionChange?(detecting)
	}
}
