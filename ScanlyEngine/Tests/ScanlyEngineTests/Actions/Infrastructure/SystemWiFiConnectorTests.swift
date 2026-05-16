//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
import Foundation
import NetworkExtension
import Testing

struct SystemWiFiConnectorTests {
	// MARK: - outcome(for:)

	@Test
	func `outcome maps a nil error to connected`() {
		#expect(SystemWiFiConnector.outcome(for: nil) == .connected)
	}

	@Test
	func `outcome maps an already-associated error to connected`() {
		#expect(SystemWiFiConnector.outcome(for: hotspotError(.alreadyAssociated)) == .connected)
	}

	@Test
	func `outcome maps a user-denied error to userCancelled`() {
		#expect(SystemWiFiConnector.outcome(for: hotspotError(.userDenied)) == .userCancelled)
	}

	@Test
	func `outcome maps any other hotspot error to failed`() {
		#expect(SystemWiFiConnector.outcome(for: hotspotError(.unknown)) == .failed)
	}

	@Test
	func `outcome maps an error from a foreign domain to failed`() {
		let error = NSError(domain: "com.example.other", code: 1)
		#expect(SystemWiFiConnector.outcome(for: error) == .failed)
	}

	// MARK: - configuration(for:)

	@Test
	func `configuration marks a hidden network hidden`() {
		let credentials = WiFiCredentials(ssid: "Stealth", security: .none, isHidden: true)

		#expect(SystemWiFiConnector.configuration(for: credentials).hidden)
	}

	@Test
	func `configuration leaves a visible network not hidden`() {
		let credentials = WiFiCredentials(ssid: "Cafe", security: .none, isHidden: false)

		#expect(SystemWiFiConnector.configuration(for: credentials).hidden == false)
	}

	// MARK: - Helpers

	private func hotspotError(_ code: NEHotspotConfigurationError) -> NSError {
		NSError(domain: NEHotspotConfigurationErrorDomain, code: code.rawValue)
	}
}
