//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import ScanlyUI
import SwiftData
import SwiftUI

private enum AppTab: Hashable {
	case scanner
	case history
}

/// Composite key for the scanner-lifecycle `.task`. SwiftUI re-runs
/// the task whenever this value changes, so any transition that
/// matters (tab change, scenePhase change) fans into a single
/// start/stop decision below.
private struct ScannerLifecycleKey: Hashable {
	let tab: AppTab
	let scenePhase: ScenePhase
}

struct ContentView: View {
	@State private var scanner: AVFoundationQRScanner
	/// Stored in `@State` so SwiftUI keeps the same coordinator
	/// instance across diff passes — `ContentView.init` would
	/// otherwise rebuild it (and a fresh `ModelContext` underneath)
	/// on every parent re-render.
	@State private var coordinator: ScanResultCoordinator
	/// Same `@State` rationale as `coordinator`. The view-model
	/// also accumulates UI state (selection, search query) that
	/// must survive a parent re-render.
	@State private var historyViewModel: HistoryViewModel
	/// Hoisted from `ScannerView` so `ContentView` can drive the
	/// capture-session lifecycle from a TabView-level `.task` keyed
	/// on `selectedTab` + `scenePhase`. `ScannerView`'s own
	/// `.onAppear` / `.onDisappear` / `.task` don't re-fire reliably
	/// on tab return (same trap that the History tab's `.onChange`
	/// reload works around), so the lifecycle has to live on a view
	/// that *is* always in the hierarchy — this one.
	@State private var scannerViewModel: ScannerViewModel
	@State private var selectedTab: AppTab = .scanner
	@Environment(\.scenePhase) private var scenePhase

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
		let scanner = AVFoundationQRScanner()
		let repository = SwiftDataScanHistoryRepository(context: ModelContext(modelContainer))
		let coordinator = ScanResultCoordinator(repository: repository)
		_scanner = State(wrappedValue: scanner)
		_coordinator = State(wrappedValue: coordinator)
		_historyViewModel = State(wrappedValue: HistoryViewModel(repository: repository))
		_scannerViewModel = State(wrappedValue: ScannerViewModel(
			scanner: scanner,
			torch: scanner,
			haptics: UIKitHapticFeedback(),
			sound: SystemSoundDetectionPlayer(),
			settings: UserDefaultsScannerSettings(defaults: .standard),
			coordinator: coordinator,
			clock: Date.init,
		))
	}

	var body: some View {
		TabView(selection: $selectedTab) {
			ScannerView(
				viewModel: scannerViewModel,
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
		.task(id: ScannerLifecycleKey(tab: selectedTab, scenePhase: scenePhase)) {
			// Single source of truth for "is the camera supposed to be
			// running right now?" The capture session is live only when
			// the Scanner tab is selected AND the app is foregrounded;
			// every other state stops it. `ScannerViewModel.start()` is
			// idempotent against `.scanning` / `.starting` so spurious
			// re-fires of the same composite key are safe.
			if selectedTab == .scanner, scenePhase == .active {
				await scannerViewModel.start()
			} else {
				scannerViewModel.stop()
			}
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
