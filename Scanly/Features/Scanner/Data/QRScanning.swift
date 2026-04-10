//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

@MainActor
protocol QRScanning: AnyObject {
	var onScan: ((String) -> Void)? { get set }
	var onDetectionChange: ((Bool) -> Void)? { get set }
	func start() async throws
	func stop()
	/// Constrains detection to `layerRect`, expressed in the preview layer's coordinate space.
	func setRegionOfInterest(_ layerRect: CGRect)
}
