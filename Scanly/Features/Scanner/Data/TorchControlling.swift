//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

@MainActor
protocol TorchControlling: AnyObject {
	var isTorchAvailable: Bool { get }
	func setTorch(_ enabled: Bool) throws
}
