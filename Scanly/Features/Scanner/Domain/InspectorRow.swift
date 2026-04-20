//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

/// One labeled field inside the result sheet's inspector. Labels can be
/// either a string catalog key (for domain-defined components like
/// "Scheme" / "SSID") or a verbatim string (for user-supplied names
/// that shouldn't be translated — e.g. URL query parameter keys).
nonisolated struct InspectorRow: Equatable {
	enum Label: Equatable {
		case localized(LocalizedStringResource)
		case verbatim(String)
	}

	let label: Label
	let value: String

	static func localized(_ key: LocalizedStringResource, value: String) -> InspectorRow {
		InspectorRow(label: .localized(key), value: value)
	}

	static func verbatim(_ label: String, value: String) -> InspectorRow {
		InspectorRow(label: .verbatim(label), value: value)
	}
}
