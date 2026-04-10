//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AVFoundation

/// Split from `QRScanning` so the view model stays free of AVFoundation.
@MainActor
protocol CameraPreviewProviding: AnyObject {
	var previewLayer: AVCaptureVideoPreviewLayer { get }
}
