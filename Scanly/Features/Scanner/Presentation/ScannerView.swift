//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AVFoundation
import PhotosUI
import SwiftUI

struct ScannerView: View {
	@State private var viewModel: ScannerViewModel
	@State private var focusIndicator: FocusIndicatorState?
	@State private var focusIndicatorHideTask: Task<Void, Never>?
	@State private var photoPickerItem: PhotosPickerItem?
	@State private var imageDetectionErrorMessage: String?
	private let previewProvider: any CameraPreviewProviding
	private let cameraControls: any CameraControlling
	private let imageDetector: any ImageBarcodeDetecting
	@Environment(\.scenePhase) private var scenePhase

	init(
		viewModel: ScannerViewModel,
		previewProvider: any CameraPreviewProviding,
		cameraControls: any CameraControlling,
		imageDetector: any ImageBarcodeDetecting,
	) {
		_viewModel = State(wrappedValue: viewModel)
		self.previewProvider = previewProvider
		self.cameraControls = cameraControls
		self.imageDetector = imageDetector
	}

	var body: some View {
		@Bindable var viewModel = viewModel
		ZStack {
			CameraPreviewView(previewLayer: previewProvider.previewLayer)
				.ignoresSafeArea()
				.contentShape(.rect)
				.onTapGesture(coordinateSpace: .local) { location in
					cameraControls.focus(at: location)
					showFocusIndicator(at: location)
				}

			if let focusIndicator {
				FocusRing()
					.position(focusIndicator.location)
					.id(focusIndicator.id)
					.transition(.opacity.combined(with: .scale(scale: 1.4)))
					.allowsHitTesting(false)
			}

			overlay
		}
		.task(id: scenePhase) {
			switch scenePhase {
			case .active:
				await viewModel.start()

			case .inactive, .background:
				viewModel.stop()

			@unknown default:
				break
			}
		}
		.onDisappear {
			viewModel.stop()
		}
		.sheet(item: $viewModel.latestResult) { result in
			ScanResultSheet(result: result)
				.presentationDetents([.height(220), .medium, .large])
				.presentationBackground(.thinMaterial)
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

@MainActor
private final class PreviewScannerStub: QRScanning, CameraPreviewProviding, TorchControlling, CameraControlling {
	let previewLayer = AVCaptureVideoPreviewLayer()
	var onScan: ((String, BarcodeFormat) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?
	var isTorchAvailable: Bool {
		true
	}

	func start() async throws {}
	func stop() {}
	func setTorch(_: Bool) throws {}
	func setRegionOfInterest(_: CGRect) {}
	func focus(at _: CGPoint) {}
}

@MainActor
private final class PreviewImageDetector: ImageBarcodeDetecting {
	func detect(in _: Data) async throws -> DetectedBarcode? {
		nil
	}
}

@MainActor
private final class PreviewHapticFeedback: HapticFeedbackControlling {
	func playSuccess() {}
}

#Preview {
	let stub = PreviewScannerStub()
	return ScannerView(
		viewModel: ScannerViewModel(
			scanner: stub,
			torch: stub,
			haptics: PreviewHapticFeedback(),
			clock: Date.init,
		),
		previewProvider: stub,
		cameraControls: stub,
		imageDetector: PreviewImageDetector(),
	)
}
