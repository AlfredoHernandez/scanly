//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@State private var scanner = AVFoundationQRScanner()

	var body: some View {
		ScannerView(
			viewModel: ScannerViewModel(
				scanner: scanner,
				torch: scanner,
				haptics: UIKitHapticFeedback(),
				sound: SystemSoundDetectionPlayer(),
				settings: UserDefaultsScannerSettings(),
				clock: Date.init,
			),
			previewProvider: scanner,
			cameraControls: scanner,
			imageDetector: VisionImageBarcodeDetector(),
		)
	}
}

#Preview {
	ContentView()
}
