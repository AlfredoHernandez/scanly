//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import OSLog

public extension Logger {
	nonisolated static let subsystem = "io.alfredohdz.Scanly"

	nonisolated static let scanner = Logger(subsystem: subsystem, category: "scanner")
	nonisolated static let history = Logger(subsystem: subsystem, category: "history")
}
