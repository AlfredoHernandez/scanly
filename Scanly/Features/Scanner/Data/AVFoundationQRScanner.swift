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
	/// Most recent metadata-space rect, read by in-flight ROI tasks so that
	/// any burst of pushes collapses to "whoever runs last wins with the
	/// latest value" regardless of Task scheduling order.
	private var latestMetadataROI: CGRect?
	private var roiPushTask: Task<Void, Never>?
	/// Same last-writer-wins pattern for focus point pushes.
	private var latestFocusDevicePoint: CGPoint?
	private var focusPushTask: Task<Void, Never>?
	/// Same last-writer-wins pattern for zoom pushes; a rapid pinch can
	/// emit many updates per frame and we only care about the final one.
	private var latestZoomFactor: CGFloat?
	private var zoomPushTask: Task<Void, Never>?

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
		latestMetadataROI = metadataRect
		roiPushTask?.cancel()
		roiPushTask = Task { [core, weak self] in
			guard let rect = self?.latestMetadataROI else { return }
			await core.setRectOfInterest(rect)
		}
	}

	func focus(at layerPoint: CGPoint) {
		let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
		latestFocusDevicePoint = devicePoint
		focusPushTask?.cancel()
		focusPushTask = Task { [core, weak self] in
			guard let point = self?.latestFocusDevicePoint else { return }
			await core.focus(at: point)
		}
	}

	func setZoomFactor(_ factor: CGFloat) {
		let clamped = min(max(factor, minZoomFactor), maxZoomFactor)
		latestZoomFactor = clamped
		zoomPushTask?.cancel()
		zoomPushTask = Task { [core, weak self] in
			guard let value = self?.latestZoomFactor else { return }
			await core.setZoomFactor(value)
		}
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
