//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
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
	/// An alert the action layer is requesting the sheet to present.
	/// A single enum (rather than several booleans) keeps at most one
	/// alert active, matching SwiftUI's one-`.alert`-per-view limit
	/// (§10.3.3).
	public enum Alert: Equatable {
		/// No alert requested.
		case none

		/// Confirm opening a scanned URL before handing it to the
		/// system (§10.3.3).
		case urlConfirmation(URL)

		/// The URL awaiting confirmation, when this is `.urlConfirmation`.
		var confirmingURL: URL? {
			if case let .urlConfirmation(url) = self { url } else { nil }
		}
	}

	/// The scan the sheet is presenting. Drives the detail content and
	/// the derived primary action.
	public let result: ScanResult

	/// The per-type primary call-to-action for the presented scan,
	/// derived per §10.3.2. Fixed for the lifetime of the view model.
	public let primaryAction: ScanResultPrimaryAction

	/// The alert the sheet should present, or `.none`.
	public private(set) var activeAlert: Alert = .none

	private let pasteboard: Pasteboard
	private let sharing: Sharing
	private let urlOpener: URLOpening

	public init(
		result: ScanResult,
		pasteboard: Pasteboard,
		sharing: Sharing,
		urlOpener: URLOpening,
	) {
		self.result = result
		primaryAction = ScanResultPrimaryAction(for: result)
		self.pasteboard = pasteboard
		self.sharing = sharing
		self.urlOpener = urlOpener
	}

	/// Whether an alert is blocking the sheet. The sheet disables
	/// swipe-to-dismiss and its Done button while this is `true`
	/// (§10.3.3).
	public var isAlertActive: Bool {
		activeAlert != .none
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

	/// Fires the per-type primary call-to-action (§10.3.2). Opening a URL
	/// is gated behind a confirmation alert (§10.3.3); other actions run
	/// directly.
	public func performPrimaryAction() {
		switch primaryAction {
		case let .openURL(url):
			activeAlert = .urlConfirmation(url)

		case .share:
			share()

		// Wired in later §10.3 steps.
		case .connectWiFi, .addContact, .call, .composeEmail, .sendSMS, .openMaps:
			break
		}
	}

	/// Confirms the URL-confirmation alert: clears it and hands the URL
	/// to the system (§10.3.3). No-op unless a URL confirmation is
	/// currently active.
	///
	/// Synchronous so the alert clears on the same run-loop turn as the
	/// button tap. Clearing it from an async hop instead would leave
	/// `activeAlert` set while the alert dismisses, and SwiftUI would
	/// re-present it from the still-true `isPresented` binding.
	public func confirmURLOpen() {
		guard case let .urlConfirmation(url) = activeAlert else { return }
		activeAlert = .none
		Task { await urlOpener.open(url) }
	}

	/// Dismisses the active alert without performing its action.
	public func dismissAlert() {
		activeAlert = .none
	}
}
