//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Vision

struct VisionImageBarcodeDetector: ImageBarcodeDetecting {
	func detect(in imageData: Data) async throws -> DetectedBarcode? {
		try await Task.detached(priority: .userInitiated) {
			let request = VNDetectBarcodesRequest()
			let handler = VNImageRequestHandler(data: imageData, options: [:])
			try handler.perform([request])
			guard let first = request.results?.first,
			      let payload = first.payloadStringValue
			else { return nil }
			return DetectedBarcode(content: payload, format: first.symbology.barcodeFormat)
		}.value
	}
}
