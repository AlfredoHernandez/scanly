//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

@MainActor
final class UIKitHapticFeedback: HapticFeedbackControlling {
	private let generator = UINotificationFeedbackGenerator()

	func playSuccess() {
		generator.notificationOccurred(.success)
	}
}
