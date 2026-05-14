//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import SwiftData
import SwiftUI

/// App entry point and top-level composition root. Owns the shared
/// SwiftData `ModelContainer` for the process lifetime so the scanner
/// (saves) and the eventual history UI (reads) bind to the same store
/// without re-opening the on-disk database.
@main
struct ScanlyApp: App {
	/// Shared SwiftData container for the history feature (§10.2).
	/// Owned at the app root for the process lifetime so the scanner
	/// and the eventual history UI (step 5/6) share the same store.
	private let modelContainer: ModelContainer

	init() {
		do {
			let schema = Schema([ScanHistoryEntry.self])
			modelContainer = try ModelContainer(for: schema)
		} catch {
			// The production app cannot function without a history
			// store. A fatal error here is preferable to silently
			// running with a broken seam — the only way this fails on
			// a real device is a disk-protection / migration bug, both
			// of which require a human fix anyway.
			fatalError("Failed to initialize ScanHistoryEntry container: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView(modelContainer: modelContainer)
		}
	}
}
