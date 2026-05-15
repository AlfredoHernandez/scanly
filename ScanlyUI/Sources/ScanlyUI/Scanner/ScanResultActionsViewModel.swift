//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Observation
import ScanlyEngine

/// Drives the action layer of the scan result sheet (§10.3): the
/// always-visible secondary actions and, in later steps, the per-type
/// primary call-to-action.
///
/// One instance is created per presented `ScanResult` and owned by the
/// sheet for the lifetime of that presentation.
@MainActor
@Observable
public final class ScanResultActionsViewModel {
	/// The scan the sheet is presenting. Drives the detail content and
	/// the derived primary action.
	public let result: ScanResult

	private let pasteboard: Pasteboard

	public init(result: ScanResult, pasteboard: Pasteboard) {
		self.result = result
		self.pasteboard = pasteboard
	}

	/// Copies the entire scanned payload (`rawContent`) to the pasteboard.
	/// This is the secondary "copy all" action; granular per-field copy
	/// stays in the inspector (§10.3.1).
	public func copyRawContent() {
		pasteboard.copy(result.rawContent)
	}
}
