//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// One labeled field inside the result sheet's inspector. Labels can be
/// either a string catalog key (for domain-defined components like
/// "Scheme" / "SSID") or a verbatim string (for user-supplied names
/// that shouldn't be translated — e.g. URL query parameter keys).
public nonisolated struct InspectorRow: Equatable, Sendable {
	public enum Label: Equatable, Sendable {
		case localized(LocalizedStringResource)
		case verbatim(String)
	}

	public let label: Label
	public let value: String

	public init(label: Label, value: String) {
		self.label = label
		self.value = value
	}

	public static func localized(_ key: LocalizedStringResource, value: String) -> InspectorRow {
		InspectorRow(label: .localized(key), value: value)
	}

	public static func verbatim(_ label: String, value: String) -> InspectorRow {
		InspectorRow(label: .verbatim(label), value: value)
	}
}
