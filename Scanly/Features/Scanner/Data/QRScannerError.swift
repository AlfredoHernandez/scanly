//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated enum QRScannerError: Error, Equatable {
	case cameraUnavailable
	case permissionDenied
	case configurationFailed
	case torchUnavailable

	var localizationKey: String.LocalizationValue {
		switch self {
		case .cameraUnavailable: "scanner.error.camera_unavailable"

		case .permissionDenied: "scanner.error.permission_denied"

		case .configurationFailed: "scanner.error.configuration_failed"

		case .torchUnavailable: "scanner.error.torch_unavailable"
		}
	}
}
