//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import SwiftUI

public struct ScanResultSheet: View {
	private let result: ScanResult
	@Environment(\.dismiss) private var dismiss

	public init(result: ScanResult) {
		self.result = result
	}

	public var body: some View {
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
