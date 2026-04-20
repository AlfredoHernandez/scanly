//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

@testable import Scanly
import Foundation
import Testing

struct URLBreakdownTests {
	@Test
	func `full URL exposes every component`() throws {
		let url = try #require(URL(string: "https://user:pass@api.example.com:8443/v1/users?page=2&limit=50#details"))
		let sut = URLBreakdown(url: url)
		#expect(sut.scheme == "https")
		#expect(sut.host == "api.example.com")
		#expect(sut.port == 8443)
		#expect(sut.path == "/v1/users")
		#expect(sut.queryItems == [URLQueryItem(name: "page", value: "2"), URLQueryItem(name: "limit", value: "50")])
		#expect(sut.fragment == "details")
	}

	@Test
	func `host-only URL reports nil for absent components`() throws {
		let url = try #require(URL(string: "https://example.com"))
		let sut = URLBreakdown(url: url)
		#expect(sut.scheme == "https")
		#expect(sut.host == "example.com")
		#expect(sut.port == nil)
		#expect(sut.path == nil)
		#expect(sut.queryItems.isEmpty)
		#expect(sut.fragment == nil)
	}

	@Test
	func `root path is treated as no path`() throws {
		let url = try #require(URL(string: "https://example.com/"))
		#expect(URLBreakdown(url: url).path == nil)
	}

	@Test
	func `non-root path is preserved verbatim`() throws {
		let url = try #require(URL(string: "https://example.com/some/nested/path"))
		#expect(URLBreakdown(url: url).path == "/some/nested/path")
	}

	@Test
	func `query items preserve order and percent-decoded values`() throws {
		let url = try #require(URL(string: "https://example.com/?q=hello%20world&lang=es"))
		let items = URLBreakdown(url: url).queryItems
		#expect(items == [
			URLQueryItem(name: "q", value: "hello world"),
			URLQueryItem(name: "lang", value: "es"),
		])
	}

	@Test
	func `query item without value has nil value`() throws {
		let url = try #require(URL(string: "https://example.com/?flag"))
		let items = URLBreakdown(url: url).queryItems
		#expect(items == [URLQueryItem(name: "flag", value: nil)])
	}

	@Test
	func `custom scheme URL is still broken down`() throws {
		let url = try #require(URL(string: "myapp://open?target=home"))
		let sut = URLBreakdown(url: url)
		#expect(sut.scheme == "myapp")
		#expect(sut.host == "open")
		#expect(sut.queryItems == [URLQueryItem(name: "target", value: "home")])
	}
}
