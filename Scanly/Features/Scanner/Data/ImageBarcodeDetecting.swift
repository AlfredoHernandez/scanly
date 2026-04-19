//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Decoded payload from a static image.
nonisolated struct DetectedBarcode: Equatable {
	let content: String
	let format: BarcodeFormat
}

@MainActor
protocol ImageBarcodeDetecting {
	/// Returns the first decoded barcode found in `imageData`, or `nil` if
	/// the image contains no recognizable code. Throws on decode failures
	/// that aren't just "no barcode here" — e.g. corrupted data.
	func detect(in imageData: Data) async throws -> DetectedBarcode?
}
