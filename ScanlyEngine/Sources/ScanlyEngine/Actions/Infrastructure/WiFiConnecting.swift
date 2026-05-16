//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import NetworkExtension

/// The result of a Wi-Fi connection attempt, normalized from
/// `NEHotspotConfigurationManager`'s callback (§10.3.5).
public enum WiFiConnectionOutcome: Equatable, Sendable {
	/// The network was joined — or the device was already associated
	/// with it, which §10.3.5 treats as success-equivalent.
	case connected

	/// The user declined the system "Join network?" prompt.
	case userCancelled

	/// The configuration could not be applied (wrong password, network
	/// not found, internal error, …).
	case failed
}

/// Joins a Wi-Fi network from scanned credentials. Modeled as a protocol
/// so the result-sheet Wi-Fi action can be verified with a spy instead
/// of touching `NEHotspotConfigurationManager` in tests.
@MainActor
public protocol WiFiConnecting {
	/// Applies a hotspot configuration for `credentials` and reports the
	/// normalized outcome.
	///
	/// - Parameter credentials: The scanned network credentials.
	/// - Returns: The normalized connection outcome (§10.3.5).
	func connect(_ credentials: WiFiCredentials) async -> WiFiConnectionOutcome
}

/// `WiFiConnecting` backed by `NEHotspotConfigurationManager`. Requires
/// the `com.apple.developer.networking.HotspotConfiguration` entitlement
/// on the host app.
@MainActor
public struct SystemWiFiConnector: WiFiConnecting {
	public init() {}

	public func connect(_ credentials: WiFiCredentials) async -> WiFiConnectionOutcome {
		let configuration = Self.configuration(for: credentials)
		return await withCheckedContinuation { continuation in
			NEHotspotConfigurationManager.shared.apply(configuration) { error in
				continuation.resume(returning: Self.outcome(for: error))
			}
		}
	}

	private nonisolated static func configuration(for credentials: WiFiCredentials) -> NEHotspotConfiguration {
		guard credentials.security != .none, let password = credentials.password else {
			return NEHotspotConfiguration(ssid: credentials.ssid)
		}
		return NEHotspotConfiguration(
			ssid: credentials.ssid,
			passphrase: password,
			isWEP: credentials.security == .wep,
		)
	}

	private nonisolated static func outcome(for error: Error?) -> WiFiConnectionOutcome {
		guard let error else { return .connected }
		let nsError = error as NSError
		guard nsError.domain == NEHotspotConfigurationErrorDomain else { return .failed }
		switch nsError.code {
		// "Already associated" means the device is already on the
		// network — success from the user's point of view (§10.3.5).
		case NEHotspotConfigurationError.alreadyAssociated.rawValue:
			return .connected

		case NEHotspotConfigurationError.userDenied.rawValue:
			return .userCancelled

		default:
			return .failed
		}
	}
}
