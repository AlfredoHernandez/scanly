//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Contacts
import ContactsUI
import Foundation
import UIKit

/// Presents the system new-contact editor for a scanned vCard. Modeled
/// as a protocol so the result-sheet contact action can be verified with
/// a spy instead of presenting Contacts UI in tests.
///
/// A Presentation-layer port: it parses the vCard and presents a
/// `CNContactViewController`, which needs a live presenting hierarchy.
@MainActor
public protocol ContactPresenting {
	/// Parses `vCard` and presents the system new-contact editor for it.
	///
	/// - Parameter vCard: The raw scanned vCard text.
	/// - Throws: `ContactPresentingError.invalidVCard` when the text is
	///   not a vCard the system can parse.
	func presentContact(fromVCard vCard: String) throws
}

/// Why a scanned contact could not be presented.
public enum ContactPresentingError: Error, Equatable {
	/// The scanned text could not be parsed as a vCard.
	case invalidVCard
}

/// `ContactPresenting` backed by `CNContactViewController`, presented
/// over the foreground scene's topmost view controller. Requires the
/// `NSContactsUsageDescription` Info.plist string.
@MainActor
public struct SystemContactPresenter: ContactPresenting {
	public init() {}

	public func presentContact(fromVCard vCard: String) throws {
		let contacts = try CNContactVCardSerialization.contacts(with: Data(vCard.utf8))
		guard let contact = contacts.first else {
			throw ContactPresentingError.invalidVCard
		}
		guard let presenter = foregroundPresenter() else { return }
		let editor = CNContactViewController(forNewContact: contact)
		editor.delegate = ContactDismisser.retained()
		// `forNewContact` expects a navigation stack so the user gets
		// Cancel / Done bar buttons.
		presenter.present(UINavigationController(rootViewController: editor), animated: true)
	}
}

/// Dismisses the contact editor when the user finishes.
///
/// `CNContactViewController.delegate` is a `weak` reference, so the
/// delegate keeps itself alive (via `selfReference`) from `retained()`
/// until the editor reports completion.
@MainActor
private final class ContactDismisser: NSObject, CNContactViewControllerDelegate {
	private var selfReference: ContactDismisser?

	static func retained() -> ContactDismisser {
		let dismisser = ContactDismisser()
		dismisser.selfReference = dismisser
		return dismisser
	}

	/// `CNContactViewControllerDelegate` is not `@MainActor`-isolated, but
	/// ContactsUI always delivers this callback on the main thread.
	nonisolated func contactViewController(
		_ viewController: CNContactViewController,
		didCompleteWith _: CNContact?,
	) {
		MainActor.assumeIsolated {
			viewController.dismiss(animated: true)
			selfReference = nil
		}
	}
}
