//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation

@MainActor
final class ScannerSettingsStub: ScannerSettingsReading {
	var isDetectionSoundEnabled: Bool

	init(isDetectionSoundEnabled: Bool = false) {
		self.isDetectionSoundEnabled = isDetectionSoundEnabled
	}
}
