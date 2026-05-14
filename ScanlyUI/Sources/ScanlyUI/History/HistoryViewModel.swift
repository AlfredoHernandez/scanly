//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import Observation
import OSLog
import ScanlyEngine

/// Drives the history list view. Loads the persisted snapshot,
/// exposes a search-filtered view of it, and forwards mutations back
/// to the repository. Errors are logged and surfaced on `state` —
/// best-effort persistence, no user-visible toast.
@MainActor
@Observable
public final class HistoryViewModel {
	public enum State: Equatable {
		case loading
		case loaded
		case failed(message: String)
	}

	public private(set) var entries: [ScanResult] = []
	public private(set) var state: State = .loading

	public var searchQuery: String = ""
	public var selection: Set<UUID> = []

	private let repository: ScanHistoryRepository

	public init(repository: ScanHistoryRepository) {
		self.repository = repository
	}

	public var visibleEntries: [ScanResult] {
		HistorySearch.filter(entries, query: searchQuery)
	}

	public func load() {
		state = .loading
		do {
			entries = try repository.all()
			state = .loaded
		} catch {
			Logger.history.error("History load failed: \(error.localizedDescription, privacy: .private)")
			entries = []
			state = .failed(message: String(localized: "history.error.load"))
		}
	}

	public func delete(_ entry: ScanResult) {
		do {
			try repository.delete(entry)
			load()
		} catch {
			Logger.history.error("History single-delete failed: \(error.localizedDescription, privacy: .private)")
		}
	}

	/// No-op when `selection` is empty so an accidental toolbar tap
	/// can't wipe the visible filter.
	public func deleteSelected() {
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

	public func deleteAll() {
		do {
			try repository.deleteAll()
			selection.removeAll()
			load()
		} catch {
			Logger.history.error("Clear history failed: \(error.localizedDescription, privacy: .private)")
		}
	}
}
