//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation

@MainActor
final class TorchSpy: TorchControlling {
	var isTorchAvailable: Bool = true
	var torchError: Error?
	private(set) var calls: [Bool] = []

	func setTorch(_ enabled: Bool) throws {
		if let torchError {
			throw torchError
		}
		calls.append(enabled)
	}
}
