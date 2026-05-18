//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import MessageUI
import ScanlyEngine

/// Opens a prefilled email composer for a scanned email payload. Modeled
/// as a protocol so the result-sheet email action can be verified with a
/// spy instead of presenting MessageUI chrome in tests.
///
/// A Presentation-layer port, not a `ScanlyEngine` adapter: it owns a
/// `UIViewController` lifecycle and needs a live presenting hierarchy.
@MainActor
public protocol MailComposing {
	/// Presents an email composer prefilled from `payload`, falling back
	/// to a `mailto:` URL when the in-app composer is unavailable.
	///
	/// - Parameter payload: The scanned email fields to prefill.
	/// - Throws: `MailComposingError.notAvailable` when the device can
	///   neither present the composer nor open a `mailto:` URL.
	func compose(_ payload: EmailPayload) async throws
}

/// Why an email composer could not be shown.
public enum MailComposingError: Error, Equatable {
	/// The device has no configured Mail account and nothing that can
	/// open a `mailto:` URL.
	case notAvailable
}

/// `MailComposing` backed by `MFMailComposeViewController`, with a
/// `mailto:` fallback (via `URLOpening`) for devices without a
/// configured Mail account (§10.3.2).
@MainActor
public struct SystemMailComposer: MailComposing {
	private let urlOpener: URLOpening

	public init(urlOpener: URLOpening) {
		self.urlOpener = urlOpener
	}

	public func compose(_ payload: EmailPayload) async throws {
		if MFMailComposeViewController.canSendMail(), let presenter = foregroundPresenter() {
			presenter.present(makeComposer(for: payload), animated: true)
			return
		}
		// No in-app composer: fall back to `mailto:` and only report
		// failure when even that has no handler (§10.3.2).
		guard let url = Self.mailtoURL(for: payload), await urlOpener.open(url) else {
			throw MailComposingError.notAvailable
		}
	}

	private func makeComposer(for payload: EmailPayload) -> MFMailComposeViewController {
		let composer = MFMailComposeViewController()
		composer.setToRecipients([payload.address])
		// Prefill only fields the scan actually carried (§10.3.2).
		if let subject = payload.subject, !subject.isEmpty {
			composer.setSubject(subject)
		}
		if let body = payload.body, !body.isEmpty {
			composer.setMessageBody(body, isHTML: false)
		}
		composer.mailComposeDelegate = MailComposeDismisser.retained()
		return composer
	}

	private static func mailtoURL(for payload: EmailPayload) -> URL? {
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = payload.address
		var queryItems: [URLQueryItem] = []
		if let subject = payload.subject, !subject.isEmpty {
			queryItems.append(URLQueryItem(name: "subject", value: subject))
		}
		if let body = payload.body, !body.isEmpty {
			queryItems.append(URLQueryItem(name: "body", value: body))
		}
		if !queryItems.isEmpty {
			components.queryItems = queryItems
		}
		return components.url
	}
}

/// Dismisses the mail composer when the user finishes.
///
/// `MFMailComposeViewController.mailComposeDelegate` is a `weak`
/// reference, so the delegate keeps itself alive (via `selfReference`)
/// from `retained()` until the composer reports completion.
@MainActor
private final class MailComposeDismisser: NSObject, MFMailComposeViewControllerDelegate {
	private var selfReference: MailComposeDismisser?

	static func retained() -> MailComposeDismisser {
		let dismisser = MailComposeDismisser()
		dismisser.selfReference = dismisser
		return dismisser
	}

	/// `MFMailComposeViewControllerDelegate` is not `@MainActor`-isolated,
	/// but MessageUI always delivers this callback on the main thread.
	nonisolated func mailComposeController(
		_ controller: MFMailComposeViewController,
		didFinishWith _: MFMailComposeResult,
		error _: Error?,
	) {
		MainActor.assumeIsolated {
			controller.dismiss(animated: true)
			selfReference = nil
		}
	}
}
