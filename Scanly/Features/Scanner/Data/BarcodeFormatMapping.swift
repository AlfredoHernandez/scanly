//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@preconcurrency import AVFoundation
import Vision

// Two mappings, one shared answer: whether scanning happens over the
// live capture session or a still image, both code paths must agree on
// what `BarcodeFormat` a given symbology corresponds to. Keeping them
// side by side here lets tests enforce that consistency.

nonisolated extension AVMetadataObject.ObjectType {
	var barcodeFormat: BarcodeFormat {
		switch self {
		case .qr: .qr

		case .dataMatrix: .dataMatrix

		case .pdf417: .pdf417

		case .aztec: .aztec

		case .code128: .code128

		case .code39: .code39

		case .ean13: .ean13

		case .ean8: .ean8

		case .upce: .upce

		default: .other
		}
	}
}

nonisolated extension VNBarcodeSymbology {
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
