//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI
import UIKit

struct ScanResultSheet: View {
	let result: ScanResult
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			Form {
				Section("scanner.result.type") {
					Text(typeLabel)
						.font(.headline)
				}

				Section("scanner.result.format") {
					Text(result.format.localizationKey)
				}

				Section("scanner.result.content") {
					Text(result.rawContent)
						.font(.body.monospaced())
						.textSelection(.enabled)
				}

				inspectorSection

				Section("scanner.result.scanned_at") {
					Text(result.scannedAt, format: .dateTime)
				}
			}
			.navigationTitle("scanner.result.title")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("scanner.result.done") { dismiss() }
				}
			}
		}
	}

	@ViewBuilder
	private var inspectorSection: some View {
		let rows = result.type.inspectorRows
		if !rows.isEmpty {
			Section {
				DisclosureGroup {
					ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
						inspectorRow(row)
					}
				} label: {
					Label("scanner.result.inspect", systemImage: "magnifyingglass")
				}
			}
		}
	}

	private func inspectorRow(_ row: InspectorRow) -> some View {
		LabeledContent {
			Text(row.value)
				.font(.body.monospaced())
				.textSelection(.enabled)
				.multilineTextAlignment(.trailing)
		} label: {
			switch row.label {
			case let .localized(key):
				Text(key)

			case let .verbatim(raw):
				Text(verbatim: raw)
			}
		}
		.contextMenu {
			Button {
				UIPasteboard.general.string = row.value
			} label: {
				Label("scanner.result.copy", systemImage: "doc.on.doc")
			}
		}
	}

	private var typeLabel: LocalizedStringKey {
		switch result.type {
		case .url:
			"scanner.type.url"

		case .wifi:
			"scanner.type.wifi"

		case .contact:
			"scanner.type.contact"

		case .phone:
			"scanner.type.phone"

		case .email:
			"scanner.type.email"

		case .sms:
			"scanner.type.sms"

		case .location:
			"scanner.type.location"

		case .text:
			"scanner.type.text"
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
