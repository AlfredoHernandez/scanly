//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// Structural view of a scanned URL — scheme, host, port, path, query,
/// fragment — so the result sheet can show each part in isolation
/// instead of dumping one opaque string at the user.
nonisolated struct URLBreakdown: Equatable {
	let scheme: String?
	let host: String?
	let port: Int?
	let path: String?
	let queryItems: [URLQueryItem]
	let fragment: String?

	init(url: URL) {
		let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
		scheme = components?.scheme
		host = components?.host
		port = components?.port
		// "/" and "" convey no information once the host is shown, so drop
		// them — the inspector only lists rows that actually add signal.
		let rawPath = components?.path ?? ""
		path = (rawPath.isEmpty || rawPath == "/") ? nil : rawPath
		queryItems = components?.queryItems ?? []
		fragment = components?.fragment
	}
}
