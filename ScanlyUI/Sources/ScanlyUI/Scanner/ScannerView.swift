//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AVFoundation
import PhotosUI
import ScanlyEngine
import SwiftUI

public struct ScannerView: View {
	@State private var viewModel: ScannerViewModel
	@State private var focusIndicator: FocusIndicatorState?
	@State private var focusIndicatorHideTask: Task<Void, Never>?
	@State private var photoPickerItem: PhotosPickerItem?
	@State private var imageDetectionErrorMessage: String?
	@State private var zoomBaseline: CGFloat = 1
	@State private var currentZoomFactor: CGFloat = 1
	@State private var isZooming = false
	@State private var zoomIndicatorHideTask: Task<Void, Never>?
	private let previewProvider: any CameraPreviewProviding
	private let cameraControls: any CameraControlling
	private let imageDetector: any ImageBarcodeDetecting
	private let makeScanResultActions: @MainActor (ScanResult) -> ScanResultActionsViewModel

	public init(
		viewModel: ScannerViewModel,
		previewProvider: any CameraPreviewProviding,
		cameraControls: any CameraControlling,
		imageDetector: any ImageBarcodeDetecting,
		makeScanResultActions: @escaping @MainActor (ScanResult) -> ScanResultActionsViewModel,
	) {
		_viewModel = State(wrappedValue: viewModel)
		self.previewProvider = previewProvider
		self.cameraControls = cameraControls
		self.imageDetector = imageDetector
		self.makeScanResultActions = makeScanResultActions
	}

	public var body: some View {
		// Pull the coordinator from the live view-model on every body
		// re-evaluation rather than capturing it once in `init`.
		// SwiftUI may re-create the view struct on parent re-renders;
		// a captured field would silently diverge from the VM's actual
		// coordinator if the composition root ever swaps it.
		@Bindable var coordinator = viewModel.coordinator
		ZStack {
			CameraPreviewView(previewLayer: previewProvider.previewLayer)
				.ignoresSafeArea()
				.contentShape(.rect)
				.onTapGesture(coordinateSpace: .local) { location in
					cameraControls.focus(at: location)
					showFocusIndicator(at: location)
				}
				.simultaneousGesture(magnifyGesture)

			if let focusIndicator {
				FocusRing()
					.position(focusIndicator.location)
					.id(focusIndicator.id)
					.transition(.opacity.combined(with: .scale(scale: 1.4)))
					.allowsHitTesting(false)
			}

			detectionHighlight

			overlay

			if isZooming {
				ZoomIndicator(factor: currentZoomFactor)
					.padding(.top, 48)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
					.transition(.opacity)
					.allowsHitTesting(false)
			}
		}
		.sheet(item: $coordinator.latestResult) { result in
			ScanResultSheet(actions: makeScanResultActions(result))
				.presentationDetents([.height(220), .medium, .large])
				.presentationBackground(.thinMaterial)
		}
		.onChange(of: coordinator.latestResult) { oldValue, newValue in
			guard oldValue != nil, newValue == nil else { return }
			Task { await viewModel.didDismissResult() }
		}
		.onChange(of: photoPickerItem) { _, newItem in
			guard let newItem else { return }
			Task { await loadAndDetect(newItem) }
		}
		.alert(
			"scanner.image.alert_title",
			isPresented: Binding(
				get: { imageDetectionErrorMessage != nil },
				set: { if !$0 { imageDetectionErrorMessage = nil } },
			),
			presenting: imageDetectionErrorMessage,
		) { _ in
			Button("OK", role: .cancel) {}
		} message: { message in
			Text(message)
		}
		.onDisappear {
			// `@State`-stored Tasks are not auto-cancelled when the view
			// is removed. If the scanner is ever embedded in a flow that
			// can dismiss it, the trailing animation closures would
			// mutate state on a vanished view.
			zoomIndicatorHideTask?.cancel()
			focusIndicatorHideTask?.cancel()
		}
	}

	private func loadAndDetect(_ item: PhotosPickerItem) async {
		defer { photoPickerItem = nil }
		guard let data = try? await item.loadTransferable(type: Data.self) else {
			imageDetectionErrorMessage = String(localized: "scanner.image.error")
			return
		}
		do {
			guard let decoded = try await imageDetector.detect(in: data) else {
				imageDetectionErrorMessage = String(localized: "scanner.image.no_barcode")
				return
			}
			viewModel.submit(content: decoded.content, format: decoded.format)
		} catch {
			imageDetectionErrorMessage = String(localized: "scanner.image.error")
		}
	}

	@ViewBuilder
	private var overlay: some View {
		switch viewModel.state {
		case .idle, .starting, .scanning, .stoppingMidStart:
			VStack {
				Spacer()
				scanReticle
				Spacer()
				torchBar
			}
			.padding()

		case let .failed(message):
			VStack(spacing: 16) {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.largeTitle)
				Text(message)
					.multilineTextAlignment(.center)
				Button("scanner.error.retry") {
					Task { await viewModel.start() }
				}
				.buttonStyle(.borderedProminent)
				.disabled(viewModel.state == .starting)
			}
			.padding(24)
			.background(.regularMaterial, in: .rect(cornerRadius: 20))
			.padding()
			.foregroundStyle(.white)
		}
	}

	private var detectionHighlight: some View {
		Group {
			if let bounds = viewModel.lastDetectionBounds {
				// `lastDetectionBounds` is in AVFoundation metadata-output
				// coords. Project to the preview layer's coord space, which
				// matches this view's local space (the preview layer fills
				// the ZStack).
				let layerRect = previewProvider.previewLayer.layerRectConverted(fromMetadataOutputRect: bounds)
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.strokeBorder(Color.green, lineWidth: 4)
					.frame(width: layerRect.width, height: layerRect.height)
					.position(x: layerRect.midX, y: layerRect.midY)
					.shadow(color: .green.opacity(0.6), radius: 8)
					.transition(.opacity.combined(with: .scale(scale: 1.05)))
					.allowsHitTesting(false)
			}
		}
		// Animation lives on the parent so SwiftUI animates **both** the
		// insertion (when bounds becomes non-nil) and the removal (when
		// it goes back to nil). Putting `.animation(...)` inside the
		// `if let` branch would only catch the insertion.
		.animation(.easeOut(duration: 0.15), value: viewModel.lastDetectionBounds)
	}

	private var scanReticle: some View {
		RoundedRectangle(cornerRadius: 24, style: .continuous)
			.strokeBorder(
				viewModel.isDetectingCode ? Color.green : Color.white.opacity(0.8),
				lineWidth: viewModel.isDetectingCode ? 5 : 3,
			)
			.frame(width: 260, height: 260)
			.shadow(
				color: viewModel.isDetectingCode ? .green.opacity(0.6) : .black.opacity(0.3),
				radius: 10,
			)
			.animation(.easeInOut(duration: 0.2), value: viewModel.isDetectingCode)
			// `.global` assumes ScannerView is a root view whose preview
			// layer starts at the window origin. If the view is ever pushed
			// inside a NavigationStack or presented modally with a non-zero
			// top inset, switch to a named coordinate space anchored on a
			// container that matches the preview layer's extent.
			.onGeometryChange(for: CGRect.self) { proxy in
				proxy.frame(in: .global)
			} action: { rect in
				cameraControls.setRegionOfInterest(rect)
			}
	}

	private var magnifyGesture: some Gesture {
		MagnifyGesture()
			.onChanged { value in
				let proposed = zoomBaseline * value.magnification
				let clamped = min(max(proposed, cameraControls.minZoomFactor), cameraControls.maxZoomFactor)
				currentZoomFactor = clamped
				cameraControls.setZoomFactor(clamped)
				showZoomIndicator()
			}
			.onEnded { _ in
				zoomBaseline = currentZoomFactor
				scheduleZoomIndicatorHide()
			}
	}

	private func showZoomIndicator() {
		zoomIndicatorHideTask?.cancel()
		if !isZooming {
			withAnimation(.easeOut(duration: 0.15)) { isZooming = true }
		}
	}

	private func scheduleZoomIndicatorHide() {
		zoomIndicatorHideTask?.cancel()
		zoomIndicatorHideTask = Task {
			try? await Task.sleep(for: .milliseconds(700))
			guard !Task.isCancelled else { return }
			withAnimation(.easeIn(duration: 0.25)) { isZooming = false }
		}
	}

	private func showFocusIndicator(at location: CGPoint) {
		focusIndicatorHideTask?.cancel()
		withAnimation(.easeOut(duration: 0.2)) {
			focusIndicator = FocusIndicatorState(location: location)
		}
		focusIndicatorHideTask = Task {
			try? await Task.sleep(for: .milliseconds(800))
			guard !Task.isCancelled else { return }
			withAnimation(.easeIn(duration: 0.3)) {
				focusIndicator = nil
			}
		}
	}

	private var torchBar: some View {
		HStack {
			if viewModel.isTorchAvailable {
				let torchLabel: LocalizedStringKey = viewModel.isTorchOn
					? "scanner.torch.off.a11y"
					: "scanner.torch.on.a11y"
				Button {
					viewModel.toggleTorch()
				} label: {
					Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
						.font(.title2)
						.frame(width: 56, height: 56)
				}
				.buttonStyle(.glass)
				.accessibilityLabel(torchLabel)
			}
			Spacer()
			PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
				Image(systemName: "photo.on.rectangle.angled")
					.font(.title2)
					.frame(width: 56, height: 56)
			}
			.buttonStyle(.glass)
			.accessibilityLabel("scanner.image.picker.a11y")
		}
	}
}

private struct FocusIndicatorState: Equatable {
	let id = UUID()
	let location: CGPoint
}

private struct FocusRing: View {
	var body: some View {
		RoundedRectangle(cornerRadius: 8, style: .continuous)
			.stroke(Color.yellow, lineWidth: 1.5)
			.frame(width: 72, height: 72)
			.shadow(color: .yellow.opacity(0.5), radius: 4)
	}
}

private struct ZoomIndicator: View {
	let factor: CGFloat

	var body: some View {
		Text(String(format: "%.1fx", factor))
			.font(.subheadline.weight(.semibold).monospacedDigit())
			.foregroundStyle(.white)
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background(.black.opacity(0.55), in: .capsule)
	}
}

@MainActor
private final class PreviewScannerStub: QRScanning, CameraPreviewProviding, TorchControlling, CameraControlling {
	let previewLayer = AVCaptureVideoPreviewLayer()
	var onScan: ((String, BarcodeFormat, CGRect) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?
	var isTorchAvailable: Bool {
		true
	}

	let minZoomFactor: CGFloat = 1
	let maxZoomFactor: CGFloat = 8

	func start() async throws {}
	func stop() {}
	func setTorch(_: Bool) throws {}
	func setRegionOfInterest(_: CGRect) {}
	func focus(at _: CGPoint) {}
	func setZoomFactor(_: CGFloat) {}
}

private struct PreviewImageDetector: ImageBarcodeDetecting {
	func detect(in _: Data) async throws -> DetectedBarcode? {
		nil
	}
}

@MainActor
private final class PreviewHapticFeedback: HapticFeedbackControlling {
	func playSuccess() {}
}

@MainActor
private final class PreviewDetectionSound: DetectionSoundPlaying {
	func playDetectionSound() {}
}

@MainActor
private final class PreviewScannerSettings: ScannerSettingsReading {
	var isDetectionSoundEnabled = false
}

#Preview {
	let stub = PreviewScannerStub()
	let coordinator = ScanResultCoordinator(repository: PreviewScanHistoryRepository())
	return ScannerView(
		viewModel: ScannerViewModel(
			scanner: stub,
			torch: stub,
			haptics: PreviewHapticFeedback(),
			sound: PreviewDetectionSound(),
			settings: PreviewScannerSettings(),
			coordinator: coordinator,
			clock: Date.init,
		),
		previewProvider: stub,
		cameraControls: stub,
		imageDetector: PreviewImageDetector(),
		makeScanResultActions: {
			let urlOpener = SystemURLOpener()
			return ScanResultActionsViewModel(
				result: $0,
				pasteboard: SystemPasteboard(),
				sharing: SystemSharing(),
				urlOpener: urlOpener,
				phoneCaller: SystemPhoneCaller(),
				mapsOpener: SystemMapsOpener(),
				mailComposer: SystemMailComposer(urlOpener: urlOpener),
				messageComposer: SystemMessageComposer(urlOpener: urlOpener),
				wifiConnector: SystemWiFiConnector(),
				contactPresenter: SystemContactPresenter(),
			)
		},
	)
}
