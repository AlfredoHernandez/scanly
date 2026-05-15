//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AudioToolbox

/// `AudioServicesPlaySystemSound`-backed player. System sounds respect
/// the silent switch automatically and need no audio-session setup.
@MainActor
public final class SystemSoundDetectionPlayer: DetectionSoundPlaying {
	/// Default `1057` — "Tink", a short neutral confirmation chime.
	private let soundID: SystemSoundID

	public init(soundID: SystemSoundID = 1057) {
		self.soundID = soundID
	}

	public func playDetectionSound() {
		AudioServicesPlaySystemSound(soundID)
	}
}
