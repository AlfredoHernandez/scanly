//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation

@MainActor
final class HapticFeedbackSpy: HapticFeedbackControlling {
	private(set) var playSuccessCallCount = 0

	func playSuccess() {
		playSuccessCallCount += 1
	}
}
