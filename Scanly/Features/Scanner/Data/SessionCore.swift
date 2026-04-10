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
		case scanned(String, epoch: Int)
		case detectionChanged(Bool, epoch: Int)

		var epoch: Int {
			switch self {
			case let .scanned(_, epoch), let .detectionChanged(_, epoch): epoch
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

	/// Idle gap after which a code is considered gone; spans ~7 frames at 30fps.
	private static let detectionIdleTimeout: Duration = .milliseconds(250)

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

	func stop() {
		desiredRunning = false
		let wasRunning = session.isRunning
		if wasRunning { session.stopRunning() }
		idleTimerTask?.cancel()
		idleTimerTask = nil
		if detectionDebouncer.reset() {
			eventContinuation.yield(.detectionChanged(false, epoch: currentEpoch))
		}
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

		let output = AVCaptureMetadataOutput()
		guard session.canAddOutput(output) else {
			throw QRScannerError.configurationFailed
		}
		session.addOutput(output)

		let delegate = MetadataDelegate(expectedQueue: sessionQueue) { [weak self] value in
			guard let self else { return }
			assumeIsolated { $0.handleObservation(value) }
		}
		metadataDelegate = delegate
		output.setMetadataObjectsDelegate(delegate, queue: sessionQueue)
		output.metadataObjectTypes = [.qr]

		isConfigured = true
	}

	private func handleObservation(_ value: String) {
		let epoch = currentEpoch
		idleTimerTask?.cancel()
		if detectionDebouncer.noteObservation() {
			eventContinuation.yield(.detectionChanged(true, epoch: epoch))
		}
		eventContinuation.yield(.scanned(value, epoch: epoch))
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
	private let handler: @Sendable (String) -> Void

	init(expectedQueue: DispatchQueue, handler: @escaping @Sendable (String) -> Void) {
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
		for object in metadataObjects {
			guard let readable = object as? AVMetadataMachineReadableCodeObject,
			      readable.type == .qr,
			      let value = readable.stringValue else { continue }
			handler(value)
			return
		}
	}
}
