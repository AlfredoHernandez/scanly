//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AudioToolbox

/// Production `DetectionSoundPlaying` backed by `AudioServicesPlaySystemSound`.
/// System sounds respect the silent switch automatically and require no
/// audio-session configuration, which keeps the scanner free of audio-route
/// concerns at the v1.0 surface.
@MainActor
public final class SystemSoundDetectionPlayer: DetectionSoundPlaying {
	/// `1057` — "Tink", a short neutral confirmation chime. Configurable
	/// at init time so the future settings UI (or a future custom-sound
	/// asset) can swap the tone without touching the scanner pipeline.
	private let soundID: SystemSoundID

	public init(soundID: SystemSoundID = 1057) {
		self.soundID = soundID
	}

	public func playDetectionSound() {
		AudioServicesPlaySystemSound(soundID)
	}
}
