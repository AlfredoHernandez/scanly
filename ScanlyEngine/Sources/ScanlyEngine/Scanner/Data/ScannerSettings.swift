//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// User-tunable scanner preferences. Today only the detection-sound
/// toggle is exposed; future settings (haptic intensity, default
/// flashlight on launch, etc.) join the same protocol.
///
/// Read-only at the seam: writes happen through the eventual
/// settings UI, which will get its own concrete writer that updates
/// the underlying `UserDefaults`. Production code only reads.
///
/// **Live-read contract:** every property getter resolves the *current*
/// value at call time — implementations must not cache. Callers may read
/// as frequently as needed and always observe settings changes made
/// through the UI without requiring invalidation or session restart.
@MainActor
public protocol ScannerSettingsReading: AnyObject {
	/// Whether the confirmation sound plays on each accepted scan.
	/// Defaults to `false` per §10.1.4 — opt-in only.
	var isDetectionSoundEnabled: Bool { get }
}

/// `UserDefaults`-backed keys for scanner preferences. Kept in one place
/// so the future settings writer, this reader, and any preview/UI code
/// all reference the same string.
public enum ScannerSettingsKeys {
	/// `Bool` — opt-in toggle for the detection-confirmation sound.
	/// Per §10.1.4 this is stored at the app level (no SwiftData entry,
	/// no per-scan persistence).
	public static let detectionSoundEnabled = "scanner.detection.sound.enabled"
}

/// `UserDefaults`-backed reader. The store is injected so previews and
/// tests can substitute an isolated suite — the composition root passes
/// `.standard` explicitly so the seam is visible at the call site.
///
/// Provides read-only access to scanner preferences persisted in
/// `UserDefaults` using keys from `ScannerSettingsKeys`.
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
