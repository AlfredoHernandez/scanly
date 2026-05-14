//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Observation

/// Top-level navigation state for the app. Today this is just the
/// selected tab; future routing concerns (deep links, presented
/// sheets, programmatic tab switches from notifications) join here so
/// the views keep depending on a single source of truth for "where
/// the user is" instead of growing their own `@State` flags.
@Observable
final class AppCoordinator {
	enum Tab: Hashable {
		case scanner
		case history
	}

	var selectedTab: Tab = .scanner
}
