//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import CoreGraphics

/// Device-level camera configuration the scanner view initiates directly
/// from UI events (geometry changes, taps). Kept separate from
/// `QRScanning` so the view model stays responsible only for scan
/// lifecycle and result state.
@MainActor
protocol CameraControlling: AnyObject {
	/// Focuses and adjusts exposure at `layerPoint`, expressed in the
	/// preview layer's coordinate space.
	func focus(at layerPoint: CGPoint)
	/// Constrains metadata detection to `layerRect` in the preview layer's
	/// coordinate space.
	func setRegionOfInterest(_ layerRect: CGRect)
}
