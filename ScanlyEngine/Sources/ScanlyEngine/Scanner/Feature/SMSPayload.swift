//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

public nonisolated struct SMSPayload: Equatable, Sendable {
	public let number: String
	public let body: String?

	public init(number: String, body: String? = nil) {
		self.number = number
		self.body = body
	}
}
