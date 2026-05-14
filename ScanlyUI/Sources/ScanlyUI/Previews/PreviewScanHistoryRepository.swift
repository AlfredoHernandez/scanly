//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

/// In-memory `ScanHistoryRepository` for SwiftUI `#Preview` blocks.
/// Two preview shapes are supported through the seed parameter: pass
/// `[]` for views that don't render rows (Scanner preview), or pass a
/// fixture array to show populated state (History list preview).
@MainActor
final class PreviewScanHistoryRepository: ScanHistoryRepository {
	private var rows: [ScanResult]

	init(seed: [ScanResult] = []) {
		rows = seed
	}

	func save(_ result: ScanResult) throws {
		rows.append(result)
	}

	func all() throws -> [ScanResult] {
		rows.sorted { $0.scannedAt > $1.scannedAt }
	}

	func delete(_ entry: ScanResult) throws {
		rows.removeAll { $0.rawContent == entry.rawContent }
	}

	func delete(_ entries: [ScanResult]) throws {
		let keys = Set(entries.map(\.rawContent))
		rows.removeAll { keys.contains($0.rawContent) }
	}

	func deleteAll() throws {
		rows.removeAll()
	}
}
