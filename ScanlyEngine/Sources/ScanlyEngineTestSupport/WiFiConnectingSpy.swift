//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine

/// Records every credential set handed to `WiFiConnecting` so tests can
/// assert which network a result-sheet action tried to join, and stubs
/// the connection outcome.
@MainActor
public final class WiFiConnectingSpy: WiFiConnecting {
	public private(set) var connectedCredentials: [WiFiCredentials] = []

	/// Stubbed outcome returned by `connect(_:)`.
	public var outcome: WiFiConnectionOutcome = .connected

	public init() {}

	public func connect(_ credentials: WiFiCredentials) async -> WiFiConnectionOutcome {
		connectedCredentials.append(credentials)
		return outcome
	}
}
