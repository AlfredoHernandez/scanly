//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated struct ScanResult: Equatable, Identifiable {
	let id: UUID
	let rawContent: String
	let type: QRType
	let format: BarcodeFormat
	let scannedAt: Date

	init(
		id: UUID = UUID(),
		rawContent: String,
		type: QRType,
		format: BarcodeFormat = .qr,
		scannedAt: Date = Date(),
	) {
		self.id = id
		self.rawContent = rawContent
		self.type = type
		self.format = format
		self.scannedAt = scannedAt
	}
}
