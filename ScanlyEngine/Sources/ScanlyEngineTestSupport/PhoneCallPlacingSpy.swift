//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine

/// Records every number handed to `PhoneCallPlacing` so tests can
/// assert which number a result-sheet action dialed, and stubs the
/// system success flag.
@MainActor
public final class PhoneCallPlacingSpy: PhoneCallPlacing {
	public private(set) var calledNumbers: [String] = []

	/// Stubbed value returned by `call(_:)`.
	public var callSucceeds = true

	public init() {}

	@discardableResult
	public func call(_ number: String) async -> Bool {
		calledNumbers.append(number)
		return callSucceeds
	}
}
