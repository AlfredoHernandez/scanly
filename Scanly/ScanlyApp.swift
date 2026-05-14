//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

struct ScanlyApp: App {
	@State private var dependencies = AppDependencies()
	@State private var coordinator = AppCoordinator()

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(\.appDependencies, dependencies)
				.environment(\.appCoordinator, coordinator)
		}
	}
}
