//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

extension EnvironmentValues {
	// `AppDependencies()` opens the production SwiftData store. Trap on
	// read instead of silently constructing it: every entry point
	// (`ScanlyApp`, previews, tests) must inject explicitly with
	// `.environment(\.appDependencies, ...)`.
	@Entry var appDependencies: AppDependencies = .missingInjection()
	@Entry var appCoordinator: AppCoordinator = .missingInjection()
}

private extension AppDependencies {
	static func missingInjection() -> AppDependencies {
		fatalError("AppDependencies was read from the environment without an injected value. Inject it from ScanlyApp or your preview/test entry point.")
	}
}

private extension AppCoordinator {
	static func missingInjection() -> AppCoordinator {
		fatalError("AppCoordinator was read from the environment without an injected value. Inject it from ScanlyApp or your preview/test entry point.")
	}
}
