//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation

@MainActor
final class ImageBarcodeDetectorSpy: ImageBarcodeDetecting {
	var result: DetectedBarcode?
	var error: Error?

	func detect(in _: Data) async throws -> DetectedBarcode? {
		if let error { throw error }
		return result
	}
}
