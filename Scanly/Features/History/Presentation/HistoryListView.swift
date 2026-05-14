//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftData
import SwiftUI

/// Surfaces the persisted scan history (§3.3 + §10.2). Rows are sorted
/// by `lastScannedAt` desc inside the repository; the view binds to
/// `viewModel.visibleEntries`, which delegates filtering to
/// `HistorySearch` so the §10.2.5 field-enumeration / exclusion
/// rules apply uniformly.
///
/// Interactions surfaced here:
/// - Tap → push `HistoryDetailView`
/// - Swipe → single-row delete
/// - Edit toolbar → multi-select + "Delete" toolbar button
/// - Menu toolbar → "Clear history" with a confirmation dialog
/// - `.searchable` → query routes through `HistorySearch`
struct HistoryListView: View {
	@State private var viewModel: HistoryViewModel
	@State private var editMode: EditMode = .inactive
	@State private var isClearAllPresented = false

	init(viewModel: HistoryViewModel) {
		_viewModel = State(wrappedValue: viewModel)
	}

	var body: some View {
		@Bindable var viewModel = viewModel
		NavigationStack {
			content
				.navigationTitle("history.title")
				.toolbar { toolbar }
				.environment(\.editMode, $editMode)
				.searchable(text: $viewModel.searchQuery, prompt: Text("history.search.prompt"))
				.confirmationDialog(
					"history.clear.confirm.title",
					isPresented: $isClearAllPresented,
					titleVisibility: .visible,
				) {
					Button("history.clear.confirm.action", role: .destructive) {
						viewModel.deleteAll()
					}
					Button("history.clear.confirm.cancel", role: .cancel) {}
				} message: {
					Text("history.clear.confirm.message")
				}
		}
		.task { viewModel.load() }
	}

	@ViewBuilder
	private var content: some View {
		switch viewModel.state {
		case .loading:
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)

		case .loaded:
			loadedList

		case let .failed(message):
			ContentUnavailableView {
				Label("history.error.title", systemImage: "exclamationmark.triangle")
			} description: {
				Text(verbatim: message)
			} actions: {
				Button("history.error.retry") { viewModel.load() }
			}
		}
	}

	@ViewBuilder
	private var loadedList: some View {
		@Bindable var viewModel = viewModel
		if viewModel.entries.isEmpty {
			ContentUnavailableView(
				"history.empty.title",
				systemImage: "clock.arrow.circlepath",
				description: Text("history.empty.body"),
			)
		} else if viewModel.visibleEntries.isEmpty {
			ContentUnavailableView.search(text: viewModel.searchQuery)
		} else {
			List(selection: $viewModel.selection) {
				ForEach(viewModel.visibleEntries) { entry in
					NavigationLink {
						HistoryDetailView(entry: entry)
					} label: {
						HistoryRow(entry: entry)
					}
				}
				.onDelete(perform: deleteRows)
			}
		}
	}

	private func deleteRows(at offsets: IndexSet) {
		// Resolve against `visibleEntries`: the user sees a filtered
		// list, and swipe-to-delete offsets are into that filtered
		// view, not the full `entries` snapshot.
		let visible = viewModel.visibleEntries
		for offset in offsets where visible.indices.contains(offset) {
			viewModel.delete(visible[offset])
		}
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			if !viewModel.entries.isEmpty {
				EditButton()
			}
		}
		ToolbarItem(placement: .topBarTrailing) {
			Menu {
				Button("history.clear.action", role: .destructive) {
					isClearAllPresented = true
				}
				.disabled(viewModel.entries.isEmpty)
			} label: {
				Image(systemName: "ellipsis.circle")
			}
		}
		if editMode == .active, !viewModel.selection.isEmpty {
			ToolbarItem(placement: .bottomBar) {
				Button("history.delete.selected", role: .destructive) {
					viewModel.deleteSelected()
				}
			}
		}
	}
}

/// One cell of the history list. Shows the type icon, a truncated
/// content preview, and the last-scanned timestamp. Detail/inspector
/// content lives in `HistoryDetailView` so the row stays scan-friendly.
private struct HistoryRow: View {
	let entry: ScanResult

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: iconName)
				.font(.title3)
				.foregroundStyle(.tint)
				.frame(width: 32)
			VStack(alignment: .leading, spacing: 4) {
				Text(entry.rawContent)
					.lineLimit(1)
					.truncationMode(.tail)
					.font(.body)
				Text(entry.scannedAt, format: .relative(presentation: .named))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.vertical, 2)
	}

	private var iconName: String {
		switch entry.type {
		case .url: "link"

		case .wifi: "wifi"

		case .email: "envelope"

		case .sms: "message"

		case .phone: "phone"

		case .location: "mappin.and.ellipse"

		case .contact: "person.crop.rectangle"

		case .text: "text.alignleft"
		}
	}
}

@MainActor
private final class PreviewScanHistoryRepository: ScanHistoryRepository {
	private var rows: [ScanResult] = [
		ScanResult(rawContent: "https://apple.com", type: .url(URL(string: "https://apple.com")!), format: .qr, scannedAt: Date(timeIntervalSinceNow: -60)),
		ScanResult(rawContent: "tel:+15551234567", type: .phone("+15551234567"), format: .qr, scannedAt: Date(timeIntervalSinceNow: -3600)),
		ScanResult(rawContent: "lunch at noon", type: .text("lunch at noon"), format: .qr, scannedAt: Date(timeIntervalSinceNow: -86400)),
	]

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

	func search(query: String) throws -> [ScanResult] {
		try HistorySearch.filter(all(), query: query)
	}
}

#Preview {
	HistoryListView(viewModel: HistoryViewModel(repository: PreviewScanHistoryRepository()))
}
