//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import CoreGraphics
import Foundation

@MainActor
public protocol QRScanning: AnyObject {
	/// Fires for each accepted scan from the live camera path. The
	/// `CGRect` is in **AVFoundation metadata-output coordinates**
	/// (normalized `[0, 1]`, origin top-left) — callers that need to
	/// render an overlay must project it into preview-layer space via
	/// `AVCaptureVideoPreviewLayer.layerRectConverted(fromMetadataOutputRect:)`.
	var onScan: ((String, BarcodeFormat, CGRect) -> Void)? { get set }
	var onDetectionChange: ((Bool) -> Void)? { get set }
	func start() async throws
	func stop()
}
