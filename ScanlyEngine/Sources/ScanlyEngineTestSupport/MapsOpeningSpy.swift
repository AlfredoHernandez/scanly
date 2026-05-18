//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import ScanlyEngine

/// Records every coordinate handed to `MapsOpening` so tests can assert
/// which location a result-sheet action opened in Maps.
@MainActor
public final class MapsOpeningSpy: MapsOpening {
	/// A coordinate recorded by the spy.
	public struct Coordinate: Equatable {
		public let latitude: Double
		public let longitude: Double

		public init(latitude: Double, longitude: Double) {
			self.latitude = latitude
			self.longitude = longitude
		}
	}

	public private(set) var openedCoordinates: [Coordinate] = []

	public init() {}

	public func openMaps(latitude: Double, longitude: Double) {
		openedCoordinates.append(Coordinate(latitude: latitude, longitude: longitude))
	}
}
