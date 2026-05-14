//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Opt-in audio confirmation that plays once per accepted scan when the
/// user has enabled the toggle (§10.1.4). Mirrors the shape of
/// `HapticFeedbackControlling` so the view model treats both feedback
/// channels uniformly.
@MainActor
public protocol DetectionSoundPlaying: AnyObject {
	/// Plays the detection-confirmation sound. The implementation
	/// honors the iOS silent-switch convention via the platform audio
	/// services — callers do not need to check the route themselves.
	func playDetectionSound()
}
