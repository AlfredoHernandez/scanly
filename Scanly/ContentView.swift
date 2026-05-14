//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import ScanlyUI
import SwiftData
import SwiftUI

/// Composite key for the scanner-lifecycle `.task`. SwiftUI re-runs
/// the task whenever this value changes, so any transition that
/// matters (tab change, scenePhase change) fans into a single
/// start/stop decision below.
private struct ScannerLifecycleKey: Hashable {
	let tab: AppCoordinator.Tab
	let scenePhase: ScenePhase
}

struct ContentView: View {
	@Environment(\.appDependencies) private var dependencies
	@Environment(\.appCoordinator) private var coordinator
	@Environment(\.scenePhase) private var scenePhase

	var body: some View {
		@Bindable var coordinator = coordinator
		TabView(selection: $coordinator.selectedTab) {
			ScannerView(
				viewModel: dependencies.scannerViewModel,
				previewProvider: dependencies.scanner,
				cameraControls: dependencies.scanner,
				imageDetector: dependencies.imageDetector,
			)
			.tabItem {
				Label("tab.scanner", systemImage: "qrcode.viewfinder")
			}
			.tag(AppCoordinator.Tab.scanner)

			HistoryListView(viewModel: dependencies.historyViewModel)
				.tabItem {
					Label("tab.history", systemImage: "clock.arrow.circlepath")
				}
				.tag(AppCoordinator.Tab.history)
		}
		.task(id: ScannerLifecycleKey(tab: coordinator.selectedTab, scenePhase: scenePhase)) {
			// Single source of truth for "is the camera supposed to be
			// running right now?" The capture session is live only when
			// the Scanner tab is selected AND the app is foregrounded.
			// `ScannerViewModel.start()` is idempotent against
			// `.scanning` / `.starting` so re-fires of the same key are
			// safe.
			if coordinator.selectedTab == .scanner, scenePhase == .active {
				await dependencies.scannerViewModel.start()
			} else {
				dependencies.scannerViewModel.stop()
			}
		}
		.task(id: coordinator.selectedTab) {
			// Single owner of the history reload trigger: fires on
			// initial render and on every change, so the list refreshes
			// when the user lands on the History tab whether it's the
			// first visit or a return from Scanner.
			if coordinator.selectedTab == .history {
				dependencies.historyViewModel.load()
			}
		}
	}
}

#Preview {
	ContentView()
		.environment(\.appDependencies, AppDependencies(modelContainer: previewContainer()))
		.environment(\.appCoordinator, AppCoordinator())
}

private func previewContainer() -> ModelContainer {
	let schema = Schema([ScanHistoryEntry.self])
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	do {
		return try ModelContainer(for: schema, configurations: [configuration])
	} catch {
		fatalError("Preview container failed to initialize: \(error)")
	}
}
