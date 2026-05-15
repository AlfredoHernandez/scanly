//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine
import SwiftUI

public struct ScanResultSheet: View {
	@State private var actions: ScanResultActionsViewModel
	@Environment(\.dismiss) private var dismiss

	public init(actions: ScanResultActionsViewModel) {
		_actions = State(wrappedValue: actions)
	}

	public var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				primaryActionButton
				ScanResultDetailContent(result: actions.result)
			}
			.navigationTitle("scanner.result.title")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("scanner.result.done") { dismiss() }
				}
				ToolbarItem(placement: .bottomBar) {
					Button("scanner.action.share", systemImage: "square.and.arrow.up") {
						actions.share()
					}
				}
				ToolbarItem(placement: .bottomBar) {
					Button("scanner.action.copy", systemImage: "doc.on.doc") {
						actions.copyRawContent()
					}
				}
			}
		}
	}

	private var primaryActionButton: some View {
		Button {
			actions.performPrimaryAction()
		} label: {
			Text(actions.primaryAction.labelKey)
				.frame(maxWidth: .infinity)
		}
		.buttonStyle(.glassProminent)
		.controlSize(.large)
		.padding()
	}
}

#Preview {
	ScanResultSheet(
		actions: ScanResultActionsViewModel(
			result: ScanResult(
				rawContent: "https://example.com/scanly",
				type: .url(URL(string: "https://example.com/scanly")!),
				format: .qr,
				scannedAt: Date(timeIntervalSince1970: 1_744_156_800),
			),
			pasteboard: SystemPasteboard(),
			sharing: SystemSharing(),
		),
	)
}
