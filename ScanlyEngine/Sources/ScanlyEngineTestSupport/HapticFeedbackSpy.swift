//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

@MainActor
public final class HapticFeedbackSpy: HapticFeedbackControlling {
	public private(set) var playSuccessCallCount = 0

	public init() {}

	public func playSuccess() {
		playSuccessCallCount += 1
	}
}
