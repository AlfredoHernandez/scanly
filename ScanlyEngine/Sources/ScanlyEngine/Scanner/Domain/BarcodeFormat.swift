//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

public nonisolated enum BarcodeFormat: String, Equatable, Sendable {
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

	public var localizationKey: LocalizedStringResource {
		switch self {
		case .qr: Self.engineString("scanner.format.qr")

		case .dataMatrix: Self.engineString("scanner.format.data_matrix")

		case .pdf417: Self.engineString("scanner.format.pdf417")

		case .aztec: Self.engineString("scanner.format.aztec")

		case .code128: Self.engineString("scanner.format.code128")

		case .code39: Self.engineString("scanner.format.code39")

		case .ean13: Self.engineString("scanner.format.ean13")

		case .ean8: Self.engineString("scanner.format.ean8")

		case .upce: Self.engineString("scanner.format.upce")

		case .other: Self.engineString("scanner.format.other")
		}
	}

	/// Pins a `LocalizedStringResource` to ScanlyEngine's bundle so
	/// callers in any module — the app target, ScanlyUI, or a future
	/// consumer — resolve the string from this package's catalog rather
	/// than `Bundle.main`. Required because format names ship with the
	/// engine that defines `BarcodeFormat`, not with the UI that
	/// happens to render them.
	private static func engineString(_ key: String.LocalizationValue) -> LocalizedStringResource {
		LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
	}
}
