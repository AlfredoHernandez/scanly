//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Observation
import OSLog

/// Owns the result-sheet presentation state and the persistence side-
/// effect that pairs with it (§10.2). `ScannerViewModel` delegates
/// here on every accepted scan; this is the only call-site that
/// invokes `ScanHistoryRepository.save(_:)`.
///
/// Why a separate type:
/// - `ScannerViewModel` stays focused on scanner-pipeline state
///   (state machine, cooldown, highlight, haptic, sound, torch,
///   pause/resume). The history side-effect is a different concern
///   with a different test seam.
/// - The history feature has a single point of write, so any future
///   change to the persistence contract (encryption, retention,
///   batching) is a single-file edit here.
/// - The view binds `.sheet(item:)` to this type's `latestResult`
///   directly — the scanner doesn't have to expose presentation state
///   to satisfy SwiftUI binding requirements.
///
/// Persistence is **best-effort** per §10.2.1: a `save` failure is
/// logged via `Logger.history.error` and the sheet is still presented
/// for the current scan. The user sees the scan; the history list
/// simply won't show it. No user-visible toast in v1.0.
@MainActor
@Observable
final class ScanResultCoordinator {
	/// The result currently being presented to the user, or `nil`
	/// when no sheet is up. The view binds `.sheet(item:)` to this
	/// property; setting it to `nil` is the dismissal signal that
	/// downstream cleanup (cooldown record, session restart) keys
	/// on.
	var latestResult: ScanResult?

	private let repository: ScanHistoryRepository

	init(repository: ScanHistoryRepository) {
		self.repository = repository
	}

	/// Persists `result` (best-effort) and publishes it as the
	/// active sheet content. Save failures are logged but never
	/// propagated — the presentation guarantee is independent of
	/// the persistence outcome per §10.2.1.
	func present(_ result: ScanResult) {
		do {
			try repository.save(result)
		} catch {
			// `error.localizedDescription` may contain payload-
			// derived text from underlying frameworks; keep it
			// `.private` so OSLog redacts it on release builds.
			Logger.history.error("History save failed: \(error.localizedDescription, privacy: .private)")
		}
		latestResult = result
	}
}
