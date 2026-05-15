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
			.interactiveDismissDisabled(actions.isAlertActive)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("scanner.result.done") { dismiss() }
						.disabled(actions.isAlertActive)
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
			.alert(
				"scanner.alert.open_url.title",
				isPresented: urlConfirmationBinding,
				presenting: actions.activeAlert.confirmingURL,
			) { _ in
				Button("scanner.alert.open") {
					actions.confirmURLOpen()
				}
				Button("scanner.alert.cancel", role: .cancel) {
					actions.dismissAlert()
				}
			} message: { url in
				Text(verbatim: urlAlertMessage(for: url))
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

	/// Drives the URL-confirmation alert from `activeAlert`. Clearing the
	/// alert on dismissal keeps `activeAlert` in sync when the user taps
	/// a button or the system dismisses it.
	private var urlConfirmationBinding: Binding<Bool> {
		Binding(
			get: { actions.activeAlert.confirmingURL != nil },
			set: { isPresented in
				if !isPresented { actions.dismissAlert() }
			},
		)
	}

	/// Host on its own line followed by the full URL (§10.3.3).
	private func urlAlertMessage(for url: URL) -> String {
		let host = URLBreakdown(url: url).host
		guard let host, !host.isEmpty else { return url.absoluteString }
		return "\(host)\n\(url.absoluteString)"
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
			urlOpener: SystemURLOpener(),
			phoneCaller: SystemPhoneCaller(),
			mapsOpener: SystemMapsOpener(),
		),
	)
}
