//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@preconcurrency import AVFoundation

@MainActor
final class AVFoundationQRScanner: QRScanning, CameraPreviewProviding, TorchControlling, CameraControlling {
	let previewLayer: AVCaptureVideoPreviewLayer
	let isTorchAvailable: Bool
	let minZoomFactor: CGFloat
	let maxZoomFactor: CGFloat
	var onScan: ((String, BarcodeFormat) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?

	private let core: SessionCore
	private var eventPump: Task<Void, Never>?
	/// Most recent reticle rect in the preview layer's coordinate space.
	/// Retained across stop/start so the ROI is re-applied on every
	/// `start()` without requiring the view to re-publish a layout change.
	private var lastLayerROI: CGRect?
	private let roiPusher: LastWriterWinsPusher<CGRect>
	private let focusPusher: LastWriterWinsPusher<CGPoint>
	private let zoomPusher: LastWriterWinsPusher<CGFloat>

	/// Hard ceiling on zoom exposed to the UI. Devices report hardware
	/// maximums in the 100s, but framing a barcode past this is unusable.
	private static let uiMaxZoomFactor: CGFloat = 8

	init() {
		let session = AVCaptureSession()
		let queue = DispatchSerialQueue(label: "io.alfredohdz.Scanly.scanner.session")
		let preview = AVCaptureVideoPreviewLayer(session: session)
		preview.videoGravity = .resizeAspectFill
		previewLayer = preview
		// Torch availability and zoom range are device-fixed properties;
		// probe once at init instead of hitting AVFoundation on every
		// SwiftUI re-render.
		let device = AVCaptureDevice.default(for: .video)
		isTorchAvailable = device?.hasTorch ?? false
		minZoomFactor = device?.minAvailableVideoZoomFactor ?? 1
		let deviceMax = device?.maxAvailableVideoZoomFactor ?? 1
		maxZoomFactor = min(deviceMax, Self.uiMaxZoomFactor)
		let core = SessionCore(session: session, queue: queue)
		self.core = core
		roiPusher = LastWriterWinsPusher { [core] rect in
			await core.setRectOfInterest(rect)
		}
		focusPusher = LastWriterWinsPusher { [core] point in
			await core.focus(at: point)
		}
		zoomPusher = LastWriterWinsPusher { [core] factor in
			await core.setZoomFactor(factor)
		}
		eventPump = Task { [weak self] in
			for await event in core.events {
				guard let self else { return }
				// Drop events stamped with an older session epoch: they were
				// buffered by a session that has since been stopped.
				guard event.epoch >= core.currentEpoch else { continue }
				switch event {
				case let .scanned(value, format, _):
					onScan?(value, format)

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
		// a configured session. Dropping `.null` is safe because `start()`
		// re-invokes this method after the session is configured, recovering
		// the race where the first layout push beats session startup.
		let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: layerRect)
		guard !metadataRect.isNull else { return }
		roiPusher.push(metadataRect)
	}

	func focus(at layerPoint: CGPoint) {
		let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
		focusPusher.push(devicePoint)
	}

	func setZoomFactor(_ factor: CGFloat) {
		let clamped = min(max(factor, minZoomFactor), maxZoomFactor)
		zoomPusher.push(clamped)
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
