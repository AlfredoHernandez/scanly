//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

/// Presents the system share sheet for a piece of text. Modeled as a
/// protocol so result-sheet share actions can be verified with a spy
/// instead of presenting real UIKit chrome in tests.
///
/// This is a Presentation-layer port, not a `ScanlyEngine` adapter: it
/// owns a `UIViewController` lifecycle and needs a live presenting view
/// hierarchy (§10.3).
@MainActor
public protocol Sharing {
	/// Presents the system share sheet with `text` as the activity item.
	///
	/// - Parameter text: The raw scanned content to share (§10.3.4).
	func share(_ text: String)
}

/// `Sharing` backed by `UIActivityViewController`, presented over the
/// foreground scene's topmost view controller.
@MainActor
public struct SystemSharing: Sharing {
	public init() {}

	public func share(_ text: String) {
		guard let presenter = foregroundPresenter() else { return }
		let activityViewController = UIActivityViewController(
			activityItems: [text],
			applicationActivities: nil,
		)
		// `UIActivityViewController` traps on iPad when presented without
		// a popover anchor. v1.0 is iPhone-only (§7), but anchoring it
		// unconditionally keeps an iPad build from crashing here.
		if let popover = activityViewController.popoverPresentationController {
			popover.sourceView = presenter.view
			popover.sourceRect = CGRect(
				x: presenter.view.bounds.midX,
				y: presenter.view.bounds.midY,
				width: 0,
				height: 0,
			)
		}
		presenter.present(activityViewController, animated: true)
	}
}
