//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

@MainActor
protocol QRScanning: AnyObject {
	var onScan: ((String, BarcodeFormat) -> Void)? { get set }
	var onDetectionChange: ((Bool) -> Void)? { get set }
	func start() async throws
	func stop()
}
