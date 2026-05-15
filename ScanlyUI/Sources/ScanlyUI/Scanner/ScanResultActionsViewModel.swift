//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Observation
import ScanlyEngine

/// Drives the action layer of the scan result sheet (§10.3): the
/// always-visible secondary actions and the per-type primary
/// call-to-action.
///
/// One instance is created per presented `ScanResult` and owned by the
/// sheet for the lifetime of that presentation.
@MainActor
@Observable
public final class ScanResultActionsViewModel {
	/// The scan the sheet is presenting. Drives the detail content and
	/// the derived primary action.
	public let result: ScanResult

	/// The per-type primary call-to-action for the presented scan,
	/// derived per §10.3.2. Fixed for the lifetime of the view model.
	public let primaryAction: ScanResultPrimaryAction

	private let pasteboard: Pasteboard
	private let sharing: Sharing

	public init(result: ScanResult, pasteboard: Pasteboard, sharing: Sharing) {
		self.result = result
		primaryAction = ScanResultPrimaryAction(for: result)
		self.pasteboard = pasteboard
		self.sharing = sharing
	}

	/// Copies the entire scanned payload (`rawContent`) to the pasteboard.
	/// This is the secondary "copy all" action; granular per-field copy
	/// stays in the inspector (§10.3.1).
	public func copyRawContent() {
		pasteboard.copy(result.rawContent)
	}

	/// Shares the raw scanned payload through the system share sheet.
	/// This is the always-visible secondary action and, for plain-text
	/// scans, the primary call-to-action as well (§10.3.2, §10.3.4).
	public func share() {
		sharing.share(result.rawContent)
	}

	/// Fires the per-type primary call-to-action (§10.3.2).
	public func performPrimaryAction() {
		switch primaryAction {
		case .share:
			share()

		// Wired in later §10.3 steps.
		case .openURL, .connectWiFi, .addContact, .call, .composeEmail, .sendSMS, .openMaps:
			break
		}
	}
}
