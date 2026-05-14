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
	private let dependencies: AppDependencies
	@State private var selectedTab: AppTab = .scanner
	@Environment(\.scenePhase) private var scenePhase

	init(dependencies: AppDependencies) {
		self.dependencies = dependencies
	}

	var body: some View {
		TabView(selection: $selectedTab) {
			ScannerView(
				viewModel: dependencies.scannerViewModel,
				previewProvider: dependencies.scanner,
				cameraControls: dependencies.scanner,
				imageDetector: dependencies.imageDetector,
			)
			.tabItem {
				Label("tab.scanner", systemImage: "qrcode.viewfinder")
			}
			.tag(AppTab.scanner)

			HistoryListView(viewModel: dependencies.historyViewModel)
				.tabItem {
					Label("tab.history", systemImage: "clock.arrow.circlepath")
				}
				.tag(AppTab.history)
		}
		.task(id: ScannerLifecycleKey(tab: selectedTab, scenePhase: scenePhase)) {
			// Single source of truth for "is the camera supposed to be
			// running right now?" The capture session is live only when
			// the Scanner tab is selected AND the app is foregrounded.
			// `ScannerViewModel.start()` is idempotent against
			// `.scanning` / `.starting` so re-fires of the same key are
			// safe.
			if selectedTab == .scanner, scenePhase == .active {
				await dependencies.scannerViewModel.start()
			} else {
				dependencies.scannerViewModel.stop()
			}
		}
		.onChange(of: selectedTab) { _, new in
			// `TabView`'s `.task` is single-shot. Reload whenever the
			// user lands on the History tab so a scan committed on the
			// Scanner tab is visible on return.
			if new == .history {
				dependencies.historyViewModel.load()
			}
		}
	}
}

#Preview {
	let schema = Schema([ScanHistoryEntry.self])
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: schema, configurations: [configuration])
	return ContentView(dependencies: AppDependencies(modelContainer: container))
}
