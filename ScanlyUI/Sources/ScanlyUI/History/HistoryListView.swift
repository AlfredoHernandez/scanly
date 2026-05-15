//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import SwiftUI

/// Persisted scan history. Rows are sorted by `lastScannedAt` desc
/// inside the repository; the view binds to `viewModel.visibleEntries`,
/// which routes the `.searchable` query through `HistorySearch`.
public struct HistoryListView: View {
	@State private var viewModel: HistoryViewModel
	@State private var editMode: EditMode = .inactive
	@State private var isClearAllPresented = false

	public init(viewModel: HistoryViewModel) {
		_viewModel = State(wrappedValue: viewModel)
	}

	public var body: some View {
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
		.onChange(of: viewModel.entries.isEmpty) { _, isEmpty in
			// When a batch delete (or "Clear history") drains the
			// list, the `EditButton` disappears with it. Without
			// resetting `editMode`, the next scan that re-populates
			// the list silently re-enters edit mode on appearance.
			if isEmpty, editMode == .active {
				withAnimation { editMode = .inactive }
			}
		}
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
		// Offsets are into the filtered list the user sees, not the full
		// `entries` snapshot.
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

#Preview {
	let appleURL = URL(string: "https://apple.com")!
	let seed = [
		ScanResult(rawContent: "https://apple.com", type: .url(appleURL), format: .qr, scannedAt: Date(timeIntervalSinceNow: -60)),
		ScanResult(rawContent: "tel:+15551234567", type: .phone("+15551234567"), format: .qr, scannedAt: Date(timeIntervalSinceNow: -3600)),
		ScanResult(rawContent: "lunch at noon", type: .text("lunch at noon"), format: .qr, scannedAt: Date(timeIntervalSinceNow: -86400)),
	]
	HistoryListView(viewModel: HistoryViewModel(repository: PreviewScanHistoryRepository(seed: seed)))
}
