//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@preconcurrency import AVFoundation

@MainActor
final class AVFoundationQRScanner: QRScanning, CameraPreviewProviding, TorchControlling {
	let previewLayer: AVCaptureVideoPreviewLayer
	let isTorchAvailable: Bool
	var onScan: ((String) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?

	private let core: SessionCore
	private var eventPump: Task<Void, Never>?
	/// Most recent reticle rect in the preview layer's coordinate space.
	/// Retained across stop/start so the ROI is re-applied on every
	/// `start()` without requiring the view to re-publish a layout change.
	private var lastLayerROI: CGRect?

	init() {
		let session = AVCaptureSession()
		let queue = DispatchSerialQueue(label: "io.alfredohdz.Scanly.scanner.session")
		let preview = AVCaptureVideoPreviewLayer(session: session)
		preview.videoGravity = .resizeAspectFill
		previewLayer = preview
		// Torch availability is a device-fixed property; probe once at init
		// instead of hitting AVFoundation on every SwiftUI re-render.
		isTorchAvailable = AVCaptureDevice.default(for: .video)?.hasTorch ?? false
		let core = SessionCore(session: session, queue: queue)
		self.core = core
		eventPump = Task { [weak self] in
			for await event in core.events {
				guard let self else { return }
				// Drop events stamped with an older session epoch: they were
				// buffered by a session that has since been stopped.
				guard event.epoch >= core.currentEpoch else { continue }
				switch event {
				case let .scanned(value, _):
					onScan?(value)

				case let .detectionChanged(detecting, _):
					onDetectionChange?(detecting)
				}
			}
		}
	}

	deinit {
		eventPump?.cancel()
	}

	func start() async throws {
		try await core.start()
		// Re-push after every start: the first layout-driven push may have
		// happened before the preview layer was connected to a configured
		// session, so `metadataOutputRectConverted` returned `.null` and we
		// silently dropped it. Now the conversion works.
		pushRegionOfInterest()
	}

	func stop() {
		Task { [core] in await core.stop() }
	}

	func setRegionOfInterest(_ layerRect: CGRect) {
		lastLayerROI = layerRect
		pushRegionOfInterest()
	}

	private func pushRegionOfInterest() {
		guard let layerRect = lastLayerROI else { return }
		// Conversion returns `.null` until the preview layer is connected to
		// a configured session; leave the rect stashed for the next push.
		let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: layerRect)
		guard !metadataRect.isNull else { return }
		Task { [core] in await core.setRectOfInterest(metadataRect) }
	}

	func setTorch(_ enabled: Bool) throws {
		guard let device = AVCaptureDevice.default(for: .video),
		      device.hasTorch
		else {
			throw QRScannerError.torchUnavailable
		}
		try device.lockForConfiguration()
		defer { device.unlockForConfiguration() }
		device.torchMode = enabled ? .on : .off
	}
}
