//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

/// Pushed from `HistoryListView` when the user taps a row. The body
/// reuses `ScanResultDetailContent` so the history detail and the
/// live scan sheet render the same Form structure — same sections,
/// same inspector rows, same copy-to-clipboard context menu — without
/// duplicating the layout.
struct HistoryDetailView: View {
	let entry: ScanResult

	var body: some View {
		ScanResultDetailContent(result: entry)
			.navigationTitle("history.detail.title")
			.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	NavigationStack {
		HistoryDetailView(
			entry: ScanResult(
				rawContent: "https://example.com/scanly",
				type: .url(URL(string: "https://example.com/scanly")!),
				format: .qr,
				scannedAt: Date(timeIntervalSince1970: 1_744_156_800),
			),
		)
	}
}
