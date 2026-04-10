//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
	let previewLayer: AVCaptureVideoPreviewLayer

	func makeUIView(context _: Context) -> PreviewContainerView {
		let view = PreviewContainerView()
		view.backgroundColor = .black
		view.layer.addSublayer(previewLayer)
		return view
	}

	func updateUIView(_ uiView: PreviewContainerView, context _: Context) {
		uiView.trackedLayer = previewLayer
	}

	final class PreviewContainerView: UIView {
		weak var trackedLayer: CALayer?

		override func layoutSubviews() {
			super.layoutSubviews()
			trackedLayer?.frame = bounds
		}
	}
}
