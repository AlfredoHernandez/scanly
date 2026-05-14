//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

@main
struct ScanlyApp: App {
	@State private var dependencies = AppDependencies()

	var body: some Scene {
		WindowGroup {
			ContentView(dependencies: dependencies)
		}
	}
}
