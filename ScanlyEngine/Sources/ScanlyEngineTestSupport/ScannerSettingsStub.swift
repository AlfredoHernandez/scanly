//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

@MainActor
public final class ScannerSettingsStub: ScannerSettingsReading {
	public var isDetectionSoundEnabled: Bool

	public init(isDetectionSoundEnabled: Bool = false) {
		self.isDetectionSoundEnabled = isDetectionSoundEnabled
	}
}
