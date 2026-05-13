//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation

@MainActor
final class DetectionSoundPlayingSpy: DetectionSoundPlaying {
	private(set) var playDetectionSoundCallCount = 0

	func playDetectionSound() {
		playDetectionSoundCallCount += 1
	}
}
