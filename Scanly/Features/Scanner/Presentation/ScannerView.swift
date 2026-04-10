//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import AVFoundation
import SwiftUI

struct ScannerView: View {
	@State private var viewModel: ScannerViewModel
	private let previewProvider: any CameraPreviewProviding
	@Environment(\.scenePhase) private var scenePhase

	init(viewModel: ScannerViewModel, previewProvider: any CameraPreviewProviding) {
		_viewModel = State(wrappedValue: viewModel)
		self.previewProvider = previewProvider
	}

	var body: some View {
		@Bindable var viewModel = viewModel
		ZStack {
			CameraPreviewView(previewLayer: previewProvider.previewLayer)
				.ignoresSafeArea()

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
		}
	}
}

@MainActor
private final class PreviewScannerStub: QRScanning, CameraPreviewProviding, TorchControlling {
	let previewLayer = AVCaptureVideoPreviewLayer()
	var onScan: ((String) -> Void)?
	var onDetectionChange: ((Bool) -> Void)?
	var isTorchAvailable: Bool {
		true
	}

	func start() async throws {}
	func stop() {}
	func setTorch(_: Bool) throws {}
}

#Preview {
	let stub = PreviewScannerStub()
	return ScannerView(
		viewModel: ScannerViewModel(scanner: stub, torch: stub, clock: Date.init),
		previewProvider: stub,
	)
}
