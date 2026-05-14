//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftData
import SwiftUI

private enum AppTab: Hashable {
	case scanner
	case history
}

struct ContentView: View {
	@State private var scanner = AVFoundationQRScanner()
	/// Stored in `@State` so SwiftUI keeps the same coordinator
	/// instance across diff passes — `ContentView.init` would
	/// otherwise rebuild it (and a fresh `ModelContext` underneath)
	/// on every parent re-render.
	@State private var coordinator: ScanResultCoordinator
	/// Same `@State` rationale as `coordinator`. The view-model
	/// also accumulates UI state (selection, search query) that
	/// must survive a parent re-render.
	@State private var historyViewModel: HistoryViewModel
	@State private var selectedTab: AppTab = .scanner

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
		_coordinator = State(wrappedValue: ScanResultCoordinator(repository: repository))
		_historyViewModel = State(wrappedValue: HistoryViewModel(repository: repository))
	}

	var body: some View {
		TabView(selection: $selectedTab) {
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
			.tag(AppTab.scanner)

			HistoryListView(viewModel: historyViewModel)
				.tabItem {
					Label("tab.history", systemImage: "clock.arrow.circlepath")
				}
				.tag(AppTab.history)
		}
		.onChange(of: selectedTab) { _, new in
			// `TabView` keeps the History tab's `.task` from re-firing
			// after the first appearance — it's a single-shot. Reload
			// whenever the user lands on the tab so a scan committed
			// on the Scanner tab is visible on return without an app
			// relaunch.
			if new == .history {
				historyViewModel.load()
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
