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

private nonisolated extension VNBarcodeSymbology {
	var barcodeFormat: BarcodeFormat {
		switch self {
		case .qr: .qr

		case .dataMatrix: .dataMatrix

		case .pdf417: .pdf417

		case .aztec: .aztec

		case .code128: .code128

		case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: .code39

		case .ean13: .ean13

		case .ean8: .ean8

		case .upce: .upce

		default: .other
		}
	}
}
