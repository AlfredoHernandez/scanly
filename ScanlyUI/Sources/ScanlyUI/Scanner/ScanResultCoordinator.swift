//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Observation
import OSLog
import ScanlyEngine

/// Owns the result-sheet presentation state and the paired history
/// write. `ScannerViewModel` delegates here on every accepted scan —
/// the only call-site that invokes `ScanHistoryRepository.save(_:)`.
///
/// Persistence is **best-effort**: a `save` failure is logged and the
/// sheet is still presented. The user sees the scan; the history list
/// just won't show it.
@MainActor
@Observable
public final class ScanResultCoordinator {
	/// `nil` when no sheet is up. Setting it to `nil` is the dismissal
	/// signal that downstream cleanup (cooldown, session restart) keys
	/// on.
	public var latestResult: ScanResult?

	private let repository: ScanHistoryRepository

	public init(repository: ScanHistoryRepository) {
		self.repository = repository
	}

	public func present(_ result: ScanResult) {
		do {
			try repository.save(result)
		} catch {
			// `.private` so OSLog redacts payload-derived text on
			// release builds.
			Logger.history.error("History save failed: \(error.localizedDescription, privacy: .private)")
		}
		latestResult = result
	}
}
