//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import OSLog

extension Logger {
	nonisolated static let subsystem = "io.alfredohdz.Scanly"

	nonisolated static let scanner = Logger(subsystem: subsystem, category: "scanner")
}
