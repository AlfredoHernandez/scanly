//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Read-only seam over scanner preferences. Every getter resolves the
/// *current* value at call time — implementations must not cache, so
/// callers always observe changes made through the settings UI.
@MainActor
public protocol ScannerSettingsReading: AnyObject {
	/// Whether the confirmation sound plays on each accepted scan.
	/// Opt-in, defaults to `false`.
	var isDetectionSoundEnabled: Bool { get }
}

public enum ScannerSettingsKeys {
	public static let detectionSoundEnabled = "scanner.detection.sound.enabled"
}

@MainActor
public final class UserDefaultsScannerSettings: ScannerSettingsReading {
	private let defaults: UserDefaults

	public init(defaults: UserDefaults) {
		self.defaults = defaults
	}

	public var isDetectionSoundEnabled: Bool {
		defaults.bool(forKey: ScannerSettingsKeys.detectionSoundEnabled)
	}
}
