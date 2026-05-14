//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Observation
import OSLog
import ScanlyEngine

/// Drives the history list view (§3.3 + §10.2). Loads the persisted
/// snapshot from `ScanHistoryRepository`, exposes a search-filtered
/// view of it, and forwards mutations (single delete, batch delete,
/// clear all) back to the repository.
///
/// Errors from the repository are logged via `Logger.history.error`
/// and surfaced on `state`; v1.0 does not show user-visible toasts
/// (§10.2.1's best-effort contract). The list simply does not
/// observe the failed mutation.
@MainActor
@Observable
final class HistoryViewModel {
	/// Top-level lifecycle state of the history feed. The view uses
	/// it to choose between the list, an empty placeholder, and an
	/// error placeholder.
	enum State: Equatable {
		case loading
		case loaded
		case failed(message: String)
	}

	private(set) var entries: [ScanResult] = []
	private(set) var state: State = .loading

	/// Bound to the `.searchable` text field. Mutations recompute
	/// `visibleEntries` on the next render via `@Observable`
	/// tracking — no explicit `objectWillChange` plumbing required.
	var searchQuery: String = ""

	/// Selected rows for the multi-select batch-delete flow. Keys
	/// are `ScanResult.id` so the list's `selection:` binding can
	/// connect directly.
	var selection: Set<UUID> = []

	private let repository: ScanHistoryRepository

	init(repository: ScanHistoryRepository) {
		self.repository = repository
	}

	/// View-facing filtered list per the current `searchQuery`.
	/// Delegates to `HistorySearch` so the inspector exclusions
	/// (§10.2.5) are honored — searching for a Wi-Fi password or
	/// URL path never surfaces a row.
	var visibleEntries: [ScanResult] {
		HistorySearch.filter(entries, query: searchQuery)
	}

	/// Loads (or reloads) the full history snapshot. Called from
	/// the view's `.task` on first appearance, and after each
	/// successful mutation to refresh the on-screen list.
	func load() {
		do {
			entries = try repository.all()
			state = .loaded
		} catch {
			Logger.history.error("History load failed: \(error.localizedDescription, privacy: .private)")
			entries = []
			state = .failed(message: String(localized: "history.error.load"))
		}
	}

	/// Single-row delete (swipe-to-delete + per-row destructive
	/// context action). On success, reloads to refresh `entries`.
	func delete(_ entry: ScanResult) {
		do {
			try repository.delete(entry)
			load()
		} catch {
			Logger.history.error("History single-delete failed: \(error.localizedDescription, privacy: .private)")
		}
	}

	/// Batch delete from the multi-select EditMode flow (§3.3).
	/// No-op when `selection` is empty so an accidental toolbar tap
	/// can't wipe the visible filter.
	func deleteSelected() {
		guard !selection.isEmpty else { return }
		let toDelete = entries.filter { selection.contains($0.id) }
		do {
			try repository.delete(toDelete)
			selection.removeAll()
			load()
		} catch {
			Logger.history.error("History batch-delete failed: \(error.localizedDescription, privacy: .private)")
		}
	}

	/// "Clear history" action (§3.3). Wipes every row and clears
	/// any in-flight selection state so the next render starts on
	/// the empty placeholder.
	func deleteAll() {
		do {
			try repository.deleteAll()
			selection.removeAll()
			load()
		} catch {
			Logger.history.error("Clear history failed: \(error.localizedDescription, privacy: .private)")
		}
	}
}
