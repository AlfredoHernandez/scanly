//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import ScanlyEngine
@testable import ScanlyUI
import Foundation
import Testing

struct SystemMessageComposerTests {
	// MARK: - smsURL(for:)

	@Test
	func `smsURL percent-encodes an ampersand so the body is not read as truncated`() throws {
		let url = try #require(
			SystemMessageComposer.smsURL(for: SMSPayload(number: "+14155551212", body: "AT&T offer")),
		)

		#expect(!url.absoluteString.contains("AT&T"), "A raw & would split the body at the sms: handler")
		#expect(url.absoluteString.contains("body=AT%26T%20offer"))
	}

	@Test
	func `smsURL omits the body parameter when the scan carried none`() throws {
		let url = try #require(SystemMessageComposer.smsURL(for: SMSPayload(number: "+14155551212")))

		#expect(url.absoluteString == "sms:+14155551212")
	}
}
