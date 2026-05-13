//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Vision

nonisolated struct VisionImageBarcodeDetector: ImageBarcodeDetecting {
	@concurrent
	func detect(in imageData: Data) async throws -> DetectedBarcode? {
		// `@concurrent` already hops off the caller's actor; no explicit
		// `Task.detached` needed. Vision's `perform` is synchronous and
		// CPU-bound but runs here on a generic background executor.
		let request = VNDetectBarcodesRequest()
		let handler = VNImageRequestHandler(data: imageData, options: [:])
		try handler.perform([request])
		guard let first = request.results?.first,
		      let payload = first.payloadStringValue
		else { return nil }
		return DetectedBarcode(content: payload, format: first.symbology.barcodeFormat)
	}
}
