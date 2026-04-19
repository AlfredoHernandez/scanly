//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@preconcurrency import AVFoundation
import Foundation
import os

/// Custom executor pins isolation to `sessionQueue` so the delegate
/// callback can re-enter via `assumeIsolated` without hopping threads.
actor SessionCore {
	enum Event {
		case scanned(String, format: BarcodeFormat, epoch: Int)
		case detectionChanged(Bool, epoch: Int)

		var epoch: Int {
			switch self {
			case let .scanned(_, _, epoch), let .detectionChanged(_, epoch): epoch
			}
		}
	}

	nonisolated let unownedExecutor: UnownedSerialExecutor
	nonisolated let events: AsyncStream<Event>

	/// Monotonic session counter, bumped on every successful `start()`. Read
	/// nonisolated so the event pump can drop stale buffered events whose
	/// epoch is older than the current session.
	private let epochStorage = OSAllocatedUnfairLock(initialState: 0)
	nonisolated var currentEpoch: Int {
		epochStorage.withLock { $0 }
	}

	private let session: AVCaptureSession
	private let sessionQueue: DispatchSerialQueue
	private let eventContinuation: AsyncStream<Event>.Continuation

	private var isConfigured = false
	private var desiredRunning = false
	private var detectionDebouncer = DetectionDebouncer()
	private var idleTimerTask: Task<Void, Never>?
	private var metadataDelegate: MetadataDelegate?
	/// Retained across stop/start: writing `rectOfInterest` on it is a
	/// no-op when the session isn't running but survives the next start.
	private var metadataOutput: AVCaptureMetadataOutput?
	/// The device bound to the session's input; used by `focus(at:)` so
	/// focus/exposure are applied to the camera actually in use rather
	/// than the global default (which may not match on dual/triple-camera
	/// setups or front-camera configurations).
	private var videoDevice: AVCaptureDevice?
	private var desiredRectOfInterest: CGRect?

	/// Idle gap after which a code is considered gone; spans ~7 frames at 30fps.
	private static let detectionIdleTimeout: Duration = .milliseconds(250)

	/// Machine-readable code types we try to enable on `AVCaptureMetadataOutput`.
	/// The actual list is intersected with `availableMetadataObjectTypes` at
	/// configuration time, because assigning an unsupported type throws an
	/// Objective-C exception that Swift cannot catch.
	private static let desiredMetadataObjectTypes: [AVMetadataObject.ObjectType] = [
		.qr,
		.dataMatrix,
		.pdf417,
		.aztec,
		.code128,
		.code39,
		.ean13,
		.ean8,
		.upce,
	]

	init(session: AVCaptureSession, queue: DispatchSerialQueue) {
		self.session = session
		sessionQueue = queue
		unownedExecutor = queue.asUnownedSerialExecutor()
		let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
		events = stream
		eventContinuation = continuation
	}

	deinit {
		eventContinuation.finish()
	}

	func start() async throws {
		desiredRunning = true
		try await ensurePermission()
		guard desiredRunning else { return }
		try configureIfNeeded()
		guard desiredRunning else { return }
		// Bump the epoch only when we're committed to actually running this
		// session, so failed/cancelled attempts don't advance the counter.
		epochStorage.withLock { $0 += 1 }
		if !session.isRunning { session.startRunning() }
		Logger.scanner.info("Capture session started")
	}

	func setRectOfInterest(_ rect: CGRect) {
		desiredRectOfInterest = rect
		metadataOutput?.rectOfInterest = rect
	}

	func setZoomFactor(_ factor: CGFloat) {
		guard let device = videoDevice else { return }
		let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
		do {
			try device.lockForConfiguration()
			defer { device.unlockForConfiguration() }
			device.videoZoomFactor = clamped
		} catch {
			Logger.scanner.error("Zoom lock failed: \(error.localizedDescription, privacy: .public)")
		}
	}

	func focus(at devicePoint: CGPoint) {
		guard let device = videoDevice else { return }
		do {
			try device.lockForConfiguration()
			defer { device.unlockForConfiguration() }
			if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
				device.focusPointOfInterest = devicePoint
				device.focusMode = .autoFocus
			}
			if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
				device.exposurePointOfInterest = devicePoint
				device.exposureMode = .continuousAutoExposure
			}
		} catch {
			Logger.scanner.error("Focus lock failed: \(error.localizedDescription, privacy: .public)")
		}
	}

	func stop() {
		desiredRunning = false
		let wasRunning = session.isRunning
		if wasRunning { session.stopRunning() }
		idleTimerTask?.cancel()
		idleTimerTask = nil
		if detectionDebouncer.reset() {
			eventContinuation.yield(.detectionChanged(false, epoch: currentEpoch))
		}
		// Bump the epoch so any events still queued from this session are
		// dropped by the pump even if no subsequent `start()` ever runs.
		epochStorage.withLock { $0 += 1 }
		if wasRunning { Logger.scanner.info("Capture session stopped") }
	}

	private nonisolated func ensurePermission() async throws {
		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			return

		case .notDetermined:
			let granted = await AVCaptureDevice.requestAccess(for: .video)
			if !granted { throw QRScannerError.permissionDenied }

		case .denied, .restricted:
			throw QRScannerError.permissionDenied

		@unknown default:
			throw QRScannerError.permissionDenied
		}
	}

	private func configureIfNeeded() throws {
		guard !isConfigured else { return }

		session.beginConfiguration()
		defer { session.commitConfiguration() }

		guard let device = AVCaptureDevice.default(for: .video),
		      let input = try? AVCaptureDeviceInput(device: device),
		      session.canAddInput(input)
		else {
			throw QRScannerError.cameraUnavailable
		}
		session.addInput(input)
		videoDevice = device

		let output = AVCaptureMetadataOutput()
		guard session.canAddOutput(output) else {
			throw QRScannerError.configurationFailed
		}
		session.addOutput(output)

		let delegate = MetadataDelegate(expectedQueue: sessionQueue) { [weak self] value, format in
			guard let self else { return }
			assumeIsolated { $0.handleObservation(value, format: format) }
		}
		metadataDelegate = delegate
		output.setMetadataObjectsDelegate(delegate, queue: sessionQueue)
		let available = Set(output.availableMetadataObjectTypes)
		output.metadataObjectTypes = Self.desiredMetadataObjectTypes.filter(available.contains)
		if let desiredRectOfInterest {
			output.rectOfInterest = desiredRectOfInterest
		}
		metadataOutput = output

		isConfigured = true
	}

	private func handleObservation(_ value: String, format: BarcodeFormat) {
		let epoch = currentEpoch
		idleTimerTask?.cancel()
		if detectionDebouncer.noteObservation() {
			eventContinuation.yield(.detectionChanged(true, epoch: epoch))
		}
		eventContinuation.yield(.scanned(value, format: format, epoch: epoch))
		idleTimerTask = Task { [weak self] in
			try? await Task.sleep(for: Self.detectionIdleTimeout)
			guard !Task.isCancelled else { return }
			await self?.handleIdleTimeout(epoch: epoch)
		}
	}

	private func handleIdleTimeout(epoch: Int) {
		guard detectionDebouncer.noteIdleTimeout() else { return }
		eventContinuation.yield(.detectionChanged(false, epoch: epoch))
	}
}

// MARK: - MetadataDelegate

private final nonisolated class MetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate, Sendable {
	private let expectedQueue: DispatchQueue
	private let handler: @Sendable (String, BarcodeFormat) -> Void

	init(expectedQueue: DispatchQueue, handler: @escaping @Sendable (String, BarcodeFormat) -> Void) {
		self.expectedQueue = expectedQueue
		self.handler = handler
		super.init()
	}

	func metadataOutput(
		_: AVCaptureMetadataOutput,
		didOutput metadataObjects: [AVMetadataObject],
		from _: AVCaptureConnection,
	) {
		dispatchPrecondition(condition: .onQueue(expectedQueue))
		// Multi-code frames drop all but the first: the VM gates on `latestResult == nil`.
		// Type filtering is unnecessary: AVFoundation only delivers objects
		// whose type is in the output's `metadataObjectTypes`, which we set
		// to our intersected allowlist at configuration time.
		for object in metadataObjects {
			guard let readable = object as? AVMetadataMachineReadableCodeObject,
			      let value = readable.stringValue else { continue }
			handler(value, readable.type.barcodeFormat)
			return
		}
	}
}

private nonisolated extension AVMetadataObject.ObjectType {
	var barcodeFormat: BarcodeFormat {
		switch self {
		case .qr: .qr

		case .dataMatrix: .dataMatrix

		case .pdf417: .pdf417

		case .aztec: .aztec

		case .code128: .code128

		case .code39: .code39

		case .ean13: .ean13

		case .ean8: .ean8

		case .upce: .upce

		default: .other
		}
	}
}
