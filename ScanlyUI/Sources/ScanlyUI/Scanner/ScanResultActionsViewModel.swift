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

	/// The system ports the result-sheet actions depend on, bundled into
	/// one value so the view model's initializer stays a two-parameter
	/// call as the action set grows.
	public struct Dependencies {
		public let pasteboard: Pasteboard
		public let sharing: Sharing
		public let urlOpener: URLOpening
		public let phoneCaller: PhoneCallPlacing
		public let mapsOpener: MapsOpening
		public let mailComposer: MailComposing
		public let messageComposer: MessageComposing
		public let wifiConnector: WiFiConnecting
		public let contactPresenter: ContactPresenting

		public init(
			pasteboard: Pasteboard,
			sharing: Sharing,
			urlOpener: URLOpening,
			phoneCaller: PhoneCallPlacing,
			mapsOpener: MapsOpening,
			mailComposer: MailComposing,
			messageComposer: MessageComposing,
			wifiConnector: WiFiConnecting,
			contactPresenter: ContactPresenting,
		) {
			self.pasteboard = pasteboard
			self.sharing = sharing
			self.urlOpener = urlOpener
			self.phoneCaller = phoneCaller
			self.mapsOpener = mapsOpener
			self.mailComposer = mailComposer
			self.messageComposer = messageComposer
			self.wifiConnector = wifiConnector
			self.contactPresenter = contactPresenter
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

	/// A transient error message for the sheet's toast, or `nil` when no
	/// toast is showing. Set when a fire-and-forget action fails
	/// (§10.3.5).
	public private(set) var toastMessage: String?

	/// Whether an asynchronous primary action is currently running. The
	/// sheet disables the primary call-to-action while this is `true` so
	/// a rapid double-tap cannot fire the action twice.
	public private(set) var isPerformingAction = false

	private let dependencies: Dependencies

	public init(result: ScanResult, dependencies: Dependencies) {
		self.result = result
		primaryAction = ScanResultPrimaryAction(for: result)
		self.dependencies = dependencies
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
		dependencies.pasteboard.copy(result.rawContent)
	}

	/// Shares the raw scanned payload through the system share sheet.
	/// This is the always-visible secondary action and, for plain-text
	/// scans, the primary call-to-action as well (§10.3.2, §10.3.4).
	public func share() {
		dependencies.sharing.share(result.rawContent)
	}

	/// Fires the per-type primary call-to-action (§10.3.2). Opening a URL
	/// is gated behind a confirmation alert (§10.3.3); other actions run
	/// directly.
	public func performPrimaryAction() {
		switch primaryAction {
		case let .openURL(url):
			activeAlert = .urlConfirmation(url)

		case let .call(number):
			performAsyncAction { await self.placeCall(number) }

		case let .openMaps(latitude, longitude):
			dependencies.mapsOpener.openMaps(latitude: latitude, longitude: longitude)

		case let .composeEmail(payload):
			performAsyncAction { await self.composeEmail(payload) }

		case let .sendSMS(payload):
			performAsyncAction { await self.sendSMS(payload) }

		case let .connectWiFi(credentials):
			performAsyncAction { await self.connectWiFi(credentials) }

		case let .addContact(vCard):
			addContact(fromVCard: vCard)

		case .share:
			share()
		}
	}

	/// Runs an asynchronous primary action under an in-flight guard: while
	/// one is running `isPerformingAction` is `true` and the sheet disables
	/// the primary call-to-action, so a rapid double-tap fires the action
	/// only once. The synchronous cases need no guard — a modal alert or a
	/// presented composer already blocks a second tap.
	private func performAsyncAction(_ operation: @escaping () async -> Void) {
		guard !isPerformingAction else { return }
		isPerformingAction = true
		Task {
			// Clear the flag via `defer` so the primary button cannot
			// stay latched if `operation` is ever made to throw or honor
			// cancellation.
			defer { isPerformingAction = false }
			await operation()
		}
	}

	/// Places the call for a phone scan. Fire-and-forget: v1.0 surfaces no
	/// in-sheet UI for a failed call (e.g. on a Wi-Fi-only device) — see
	/// §10.3.6.
	private func placeCall(_ number: String) async {
		await dependencies.phoneCaller.call(number)
	}

	/// Presents the email composer for the scanned payload, surfacing a
	/// toast when the device can compose neither in-app mail nor a
	/// `mailto:` URL (§10.3.2).
	private func composeEmail(_ payload: EmailPayload) async {
		do {
			try await dependencies.mailComposer.compose(payload)
		} catch {
			toastMessage = String(localized: "scanner.action.email.unavailable")
		}
	}

	/// Presents the message composer for the scanned payload, surfacing a
	/// toast when the device can compose neither an in-app message nor an
	/// `sms:` URL (§10.3.2).
	private func sendSMS(_ payload: SMSPayload) async {
		do {
			try await dependencies.messageComposer.compose(payload)
		} catch {
			toastMessage = String(localized: "scanner.action.sms.unavailable")
		}
	}

	/// Joins the scanned Wi-Fi network. A failed attempt raises a toast;
	/// a user-cancelled prompt and an already-joined network both leave
	/// the sheet quietly open (§10.3.5).
	private func connectWiFi(_ credentials: WiFiCredentials) async {
		switch await dependencies.wifiConnector.connect(credentials) {
		case .connected, .userCancelled:
			break

		case .failed:
			toastMessage = String(localized: "scanner.action.wifi.failed")
		}
	}

	/// Presents the system new-contact editor for the scanned vCard,
	/// surfacing a toast when the vCard cannot be parsed (§10.3.2).
	private func addContact(fromVCard vCard: String) {
		do {
			try dependencies.contactPresenter.presentContact(fromVCard: vCard)
		} catch {
			toastMessage = String(localized: "scanner.action.contact.invalid")
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
		Task { await dependencies.urlOpener.open(url) }
	}

	/// Dismisses the active alert without performing its action.
	public func dismissAlert() {
		activeAlert = .none
	}

	/// Invoked by the toast's auto-dismiss timer to clear the error toast.
	public func dismissToast() {
		toastMessage = nil
	}
}
