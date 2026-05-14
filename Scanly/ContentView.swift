//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftData
import SwiftUI

struct ContentView: View {
	@State private var scanner = AVFoundationQRScanner()
	private let coordinator: ScanResultCoordinator
	private let historyViewModel: HistoryViewModel

	/// Wires the composition root for the scanner + history flow.
	/// Builds a single `SwiftDataScanHistoryRepository` against a
	/// fresh `ModelContext` derived from the app-owned container,
	/// then hands the same repository instance to the
	/// `ScanResultCoordinator` (the scanner's write side) and the
	/// `HistoryViewModel` (the history tab's read side). Sharing the
	/// repository means a scan saved on the Scanner tab is visible
	/// on the History tab the next time it loads — both consumers
	/// look at the same SwiftData rows.
	init(modelContainer: ModelContainer) {
		let repository = SwiftDataScanHistoryRepository(context: ModelContext(modelContainer))
		coordinator = ScanResultCoordinator(repository: repository)
		historyViewModel = HistoryViewModel(repository: repository)
	}

	var body: some View {
		TabView {
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
			.tabItem {
				Label("tab.scanner", systemImage: "qrcode.viewfinder")
			}

			HistoryListView(viewModel: historyViewModel)
				.tabItem {
					Label("tab.history", systemImage: "clock.arrow.circlepath")
				}
		}
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
