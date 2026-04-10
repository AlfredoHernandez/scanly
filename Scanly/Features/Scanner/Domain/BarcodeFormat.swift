//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated enum BarcodeFormat: String, Equatable {
	case qr
	case dataMatrix
	case pdf417
	case aztec
	case code128
	case code39
	case ean13
	case ean8
	case upce
	/// Fallback for any `AVMetadataObject.ObjectType` we don't recognize.
	case other

	var localizationKey: LocalizedStringResource {
		switch self {
		case .qr: "scanner.format.qr"

		case .dataMatrix: "scanner.format.data_matrix"

		case .pdf417: "scanner.format.pdf417"

		case .aztec: "scanner.format.aztec"

		case .code128: "scanner.format.code128"

		case .code39: "scanner.format.code39"

		case .ean13: "scanner.format.ean13"

		case .ean8: "scanner.format.ean8"

		case .upce: "scanner.format.upce"

		case .other: "scanner.format.other"
		}
	}
}
