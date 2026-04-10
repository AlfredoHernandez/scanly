//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

@MainActor
protocol HapticFeedbackControlling: AnyObject {
	/// Plays a success notification feedback pattern. Respects the user's
	/// system haptics preference automatically.
	func playSuccess()
}
