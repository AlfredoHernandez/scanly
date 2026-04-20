//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import CoreGraphics

/// Device-level camera configuration the scanner view initiates directly
/// from UI events (geometry changes, taps, pinches). Kept separate from
/// `QRScanning` so the view model stays responsible only for scan
/// lifecycle and result state.
@MainActor
protocol CameraControlling: AnyObject {
	/// Minimum zoom factor the device supports. May be less than 1 on
	/// devices with an ultrawide lens available as a virtual zoom stop.
	var minZoomFactor: CGFloat { get }
	/// Maximum zoom factor the UI exposes. Capped below the hardware
	/// maximum because barcode framing becomes unusable past ~8x.
	var maxZoomFactor: CGFloat { get }
	/// Focuses and adjusts exposure at `layerPoint`, expressed in the
	/// preview layer's coordinate space.
	func focus(at layerPoint: CGPoint)
	/// Constrains metadata detection to `layerRect` in the preview layer's
	/// coordinate space.
	func setRegionOfInterest(_ layerRect: CGRect)
	/// Applies `factor` to the active video device. Values are clamped
	/// into `[minZoomFactor, maxZoomFactor]`.
	func setZoomFactor(_ factor: CGFloat)
}
