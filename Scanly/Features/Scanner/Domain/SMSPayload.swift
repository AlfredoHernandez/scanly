//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated struct SMSPayload: Equatable {
	let number: String
	let body: String?
}
