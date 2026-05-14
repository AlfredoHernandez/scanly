//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Opt-in audio confirmation played once per accepted scan when the
/// toggle is on. Honors the iOS silent-switch convention via the
/// platform audio services.
@MainActor
public protocol DetectionSoundPlaying: AnyObject {
	func playDetectionSound()
}
