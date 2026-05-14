//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftData
import SwiftUI

struct ContentView: View {
	@State private var scanner = AVFoundationQRScanner()
	private let coordinator: ScanResultCoordinator

	init(modelContainer: ModelContainer) {
		let repository = SwiftDataScanHistoryRepository(context: ModelContext(modelContainer))
		coordinator = ScanResultCoordinator(repository: repository)
	}

	var body: some View {
		ScannerView(
			viewModel: ScannerViewModel(
				scanner: scanner,
				torch: scanner,
				haptics: UIKitHapticFeedback(),
				sound: SystemSoundDetectionPlayer(),
				settings: UserDefaultsScannerSettings(defaults: .standard),
				coordinator: coordinator,
				clock: Date.init,
			),
			previewProvider: scanner,
			cameraControls: scanner,
			imageDetector: VisionImageBarcodeDetector(),
		)
	}
}

#Preview {
	let schema = Schema([ScanHistoryEntry.self])
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	// `try!` is preview-only; production passes a real container
	// from `ScanlyApp` and fails fast at launch instead.
	let container = try! ModelContainer(for: schema, configurations: [configuration])
	return ContentView(modelContainer: container)
}
