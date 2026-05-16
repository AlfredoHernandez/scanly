//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import UIKit

/// The topmost presentable view controller of the foreground-active
/// window scene, or `nil` when no scene is currently presentable.
///
/// Shared by the result-sheet action adapters that present UIKit
/// controllers (`SystemSharing`, `SystemMailComposer`, …): they have no
/// SwiftUI host to present from, so they walk the live scene graph. A
/// controller that is mid-dismissal is skipped — presenting over it is
/// undefined behaviour.
@MainActor
func foregroundPresenter() -> UIViewController? {
	var presenter = UIApplication.shared.connectedScenes
		.compactMap { $0 as? UIWindowScene }
		.first { $0.activationState == .foregroundActive }?
		.keyWindow?
		.rootViewController
	while let presented = presenter?.presentedViewController, !presented.isBeingDismissed {
		presenter = presented
	}
	return presenter
}
