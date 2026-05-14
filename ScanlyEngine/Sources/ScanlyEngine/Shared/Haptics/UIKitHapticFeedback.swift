//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

@MainActor
public final class UIKitHapticFeedback: HapticFeedbackControlling {
	private let generator = UINotificationFeedbackGenerator()

	public init() {}

	public func playSuccess() {
		generator.notificationOccurred(.success)
	}
}
