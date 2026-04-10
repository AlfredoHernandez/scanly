//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import Foundation

nonisolated struct EmailPayload: Equatable {
	let address: String
	let subject: String?
	let body: String?
}
