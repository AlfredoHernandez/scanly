//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

@MainActor
public final class DetectionSoundPlayingSpy: DetectionSoundPlaying {
	public private(set) var playDetectionSoundCallCount = 0

	public init() {}

	public func playDetectionSound() {
		playDetectionSoundCallCount += 1
	}
}
