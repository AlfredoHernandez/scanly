//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import ScanlyUI
import SwiftUI

struct ScanResultSheet: View {
	let result: ScanResult
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScanResultDetailContent(result: result)
				.navigationTitle("scanner.result.title")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("scanner.result.done") { dismiss() }
					}
				}
		}
	}
}

#Preview {
	ScanResultSheet(
		result: ScanResult(
			rawContent: "https://example.com/scanly",
			type: .url(URL(string: "https://example.com/scanly")!),
			format: .qr,
			scannedAt: Date(timeIntervalSince1970: 1_744_156_800),
		),
	)
}
