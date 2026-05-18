//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import MessageUI
import ScanlyEngine

/// Opens a prefilled message composer for a scanned SMS payload. Modeled
/// as a protocol so the result-sheet message action can be verified with
/// a spy instead of presenting MessageUI chrome in tests.
///
/// A Presentation-layer port, not a `ScanlyEngine` adapter: it owns a
/// `UIViewController` lifecycle and needs a live presenting hierarchy.
@MainActor
public protocol MessageComposing {
	/// Presents a message composer prefilled from `payload`, falling back
	/// to an `sms:` URL when the in-app composer is unavailable.
	///
	/// - Parameter payload: The scanned SMS fields to prefill.
	/// - Throws: `MessageComposingError.notAvailable` when the device can
	///   neither present the composer nor open an `sms:` URL.
	func compose(_ payload: SMSPayload) async throws
}

/// Why a message composer could not be shown.
public enum MessageComposingError: Error, Equatable {
	/// The device cannot send text messages and has nothing that can
	/// open an `sms:` URL.
	case notAvailable
}

/// `MessageComposing` backed by `MFMessageComposeViewController`, with an
/// `sms:` fallback (via `URLOpening`) for devices that cannot send text
/// messages (§10.3.2).
@MainActor
public struct SystemMessageComposer: MessageComposing {
	private let urlOpener: URLOpening

	public init(urlOpener: URLOpening) {
		self.urlOpener = urlOpener
	}

	public func compose(_ payload: SMSPayload) async throws {
		if MFMessageComposeViewController.canSendText(), let presenter = foregroundPresenter() {
			presenter.present(makeComposer(for: payload), animated: true)
			return
		}
		// No in-app composer: fall back to `sms:` and only report
		// failure when even that has no handler (§10.3.2).
		guard let url = Self.smsURL(for: payload), await urlOpener.open(url) else {
			throw MessageComposingError.notAvailable
		}
	}

	private func makeComposer(for payload: SMSPayload) -> MFMessageComposeViewController {
		let composer = MFMessageComposeViewController()
		composer.recipients = [payload.number]
		// Prefill the body only when the scan actually carried one (§10.3.2).
		if let body = payload.body, !body.isEmpty {
			composer.body = body
		}
		composer.messageComposeDelegate = MessageComposeDismisser.retained()
		return composer
	}

	/// Builds the `sms:` fallback URL for `payload`. Module-internal
	/// (not `private`) so the body's percent-encoding stays unit-testable;
	/// `nonisolated` because it is pure string work with no UI dependency.
	nonisolated static func smsURL(for payload: SMSPayload) -> URL? {
		// `sms:` rejects raw spaces in the number; the body rides along
		// as iOS's non-standard `&body=` parameter.
		var string = "sms:" + payload.number.filter { !$0.isWhitespace }
		if let body = payload.body, !body.isEmpty {
			// `&` and `+` are valid in a query *string*, so `.urlQueryAllowed`
			// keeps them — but inside a value they must be encoded, or the
			// `sms:` handler reads the body as truncated at the first `&`.
			var bodyAllowed = CharacterSet.urlQueryAllowed
			bodyAllowed.remove(charactersIn: "&+")
			if let encoded = body.addingPercentEncoding(withAllowedCharacters: bodyAllowed) {
				string += "&body=" + encoded
			}
		}
		return URL(string: string)
	}
}

/// Dismisses the message composer when the user finishes.
///
/// `MFMessageComposeViewController.messageComposeDelegate` is a `weak`
/// reference, so the delegate keeps itself alive (via `selfReference`)
/// from `retained()` until the composer reports completion.
@MainActor
private final class MessageComposeDismisser: NSObject, MFMessageComposeViewControllerDelegate {
	private var selfReference: MessageComposeDismisser?

	static func retained() -> MessageComposeDismisser {
		let dismisser = MessageComposeDismisser()
		dismisser.selfReference = dismisser
		return dismisser
	}

	/// `MFMessageComposeViewControllerDelegate` is not `@MainActor`-isolated,
	/// but MessageUI always delivers this callback on the main thread.
	nonisolated func messageComposeViewController(
		_ controller: MFMessageComposeViewController,
		didFinishWith _: MessageComposeResult,
	) {
		MainActor.assumeIsolated {
			controller.dismiss(animated: true)
			selfReference = nil
		}
	}
}
