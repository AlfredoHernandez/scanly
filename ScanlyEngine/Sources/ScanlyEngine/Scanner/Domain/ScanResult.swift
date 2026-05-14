//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

public nonisolated struct ScanResult: Equatable, Identifiable, Sendable {
	public let id: UUID
	public let rawContent: String
	public let type: QRType
	public let format: BarcodeFormat
	public let scannedAt: Date

	public init(
		id: UUID = UUID(),
		rawContent: String,
		type: QRType,
		format: BarcodeFormat,
		scannedAt: Date = Date(),
	) {
		self.id = id
		self.rawContent = rawContent
		self.type = type
		self.format = format
		self.scannedAt = scannedAt
	}
}
