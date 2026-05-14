//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

public nonisolated struct EmailPayload: Equatable, Sendable {
	public let address: String
	public let subject: String?
	public let body: String?

	public init(address: String, subject: String? = nil, body: String? = nil) {
		self.address = address
		self.subject = subject
		self.body = body
	}
}
