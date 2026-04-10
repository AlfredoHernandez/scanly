//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Pure edge detector for "QR visible in frame". Each mutator returns `true` only on a real edge.
nonisolated struct DetectionDebouncer {
	private(set) var isDetecting = false

	mutating func noteObservation() -> Bool {
		guard !isDetecting else { return false }
		isDetecting = true
		return true
	}

	mutating func noteIdleTimeout() -> Bool {
		guard isDetecting else { return false }
		isDetecting = false
		return true
	}

	mutating func reset() -> Bool {
		guard isDetecting else { return false }
		isDetecting = false
		return true
	}
}
