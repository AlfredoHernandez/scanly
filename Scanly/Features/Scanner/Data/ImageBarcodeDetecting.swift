//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Decoded payload from a static image.
nonisolated struct DetectedBarcode: Equatable {
	let content: String
	let format: BarcodeFormat
}

/// Decodes barcodes from a static image (e.g. a photo picked from the
/// library). `Sendable` so callers — typically `@MainActor` SwiftUI views —
/// can hold a stored reference and call into it without worrying about
/// crossing isolation boundaries.
protocol ImageBarcodeDetecting: Sendable {
	/// Returns the first decoded barcode found in `imageData`, or `nil` if
	/// the image contains no recognizable code. Throws on decode failures
	/// that aren't just "no barcode here" — e.g. corrupted data.
	///
	/// `@concurrent` so the (CPU-bound) Vision work always runs off the
	/// caller's actor. `@MainActor` callers therefore await without
	/// blocking the main thread, and the protocol seam guarantees this
	/// regardless of which implementation is wired in.
	@concurrent
	func detect(in imageData: Data) async throws -> DetectedBarcode?
}
