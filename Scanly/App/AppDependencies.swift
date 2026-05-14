//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation
import ScanlyEngine
import ScanlyUI
import SwiftData

/// Composition root: owns the long-lived services, the shared
/// `ModelContainer`, and the top-level view-models for the process
/// lifetime. `ScanlyApp` holds a single instance in `@State`; views
/// pull the pre-built scanner / history wiring out instead of
/// constructing it themselves.
///
/// The `modelContainer` parameter exists so tests (and the preview)
/// can pass an in-memory container without triggering the production
/// disk store. Production callers pass nothing.
final class AppDependencies {
	let modelContainer: ModelContainer
	let scanner: AVFoundationQRScanner
	let imageDetector: VisionImageBarcodeDetector
	let repository: ScanHistoryRepository
	let scanResultCoordinator: ScanResultCoordinator
	let scannerViewModel: ScannerViewModel
	let historyViewModel: HistoryViewModel

	init(modelContainer: ModelContainer = AppDependencies.makeDefaultModelContainer()) {
		self.modelContainer = modelContainer
		let scanner = AVFoundationQRScanner()
		let repository = SwiftDataScanHistoryRepository(
			context: ModelContext(modelContainer),
			parser: QRContentParser(),
		)
		let scanResultCoordinator = ScanResultCoordinator(repository: repository)
		let scannerViewModel = ScannerViewModel(
			scanner: scanner,
			torch: scanner,
			haptics: UIKitHapticFeedback(),
			sound: SystemSoundDetectionPlayer(),
			settings: UserDefaultsScannerSettings(defaults: .standard),
			coordinator: scanResultCoordinator,
			clock: Date.init,
		)
		self.scanner = scanner
		imageDetector = VisionImageBarcodeDetector()
		self.repository = repository
		self.scanResultCoordinator = scanResultCoordinator
		self.scannerViewModel = scannerViewModel
		historyViewModel = HistoryViewModel(repository: repository)
	}

	private static func makeDefaultModelContainer() -> ModelContainer {
		do {
			let schema = Schema([ScanHistoryEntry.self])
			return try ModelContainer(for: schema)
		} catch {
			fatalError("Failed to initialize ScanHistoryEntry container: \(error)")
		}
	}
}
