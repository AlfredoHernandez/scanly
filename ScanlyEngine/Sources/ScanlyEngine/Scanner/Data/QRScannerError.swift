//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

public nonisolated enum QRScannerError: Error, Equatable, Sendable {
	case cameraUnavailable
	case permissionDenied
	case configurationFailed
	case torchUnavailable

	/// Resolved user-facing message, looked up in ScanlyEngine's own
	/// catalog. Returning a `String` rather than a key isolates callers
	/// from the engine's bundle and keeps them framework-agnostic — a
	/// SwiftUI view, a UIKit alert, or a CLI log can use the same value.
	public var localizedMessage: String {
		String(localized: localizationKey, bundle: .module)
	}

	private var localizationKey: String.LocalizationValue {
		switch self {
		case .cameraUnavailable: "scanner.error.camera_unavailable"

		case .permissionDenied: "scanner.error.permission_denied"

		case .configurationFailed: "scanner.error.configuration_failed"

		case .torchUnavailable: "scanner.error.torch_unavailable"
		}
	}
}
