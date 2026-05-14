//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine

@MainActor
public final class TorchSpy: TorchControlling {
	public var isTorchAvailable: Bool = true
	public var torchError: Error?
	public private(set) var calls: [Bool] = []

	public init() {}

	public func setTorch(_ enabled: Bool) throws {
		if let torchError {
			throw torchError
		}
		calls.append(enabled)
	}
}
