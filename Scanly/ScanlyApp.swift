//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import SwiftData
import SwiftUI

/// App entry point and composition root. Owns the shared SwiftData
/// `ModelContainer` for the process lifetime so scanner writes and
/// history reads bind to the same store.
@main
struct ScanlyApp: App {
	private let modelContainer: ModelContainer

	init() {
		do {
			let schema = Schema([ScanHistoryEntry.self])
			modelContainer = try ModelContainer(for: schema)
		} catch {
			fatalError("Failed to initialize ScanHistoryEntry container: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView(modelContainer: modelContainer)
		}
	}
}
