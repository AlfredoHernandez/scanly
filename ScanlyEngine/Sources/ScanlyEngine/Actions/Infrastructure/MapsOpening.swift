//
//  Copyright © 2026 Jesús Alfredo Hernández Alarcón. All rights reserved.
//

import CoreLocation
import MapKit

/// Opens a geographic coordinate in Maps. Modeled as a protocol so the
/// result-sheet location action can be verified with a spy instead of
/// launching Maps during tests.
@MainActor
public protocol MapsOpening {
	/// Opens the given coordinate in the Maps app.
	///
	/// - Parameters:
	///   - latitude: The coordinate's latitude, in degrees.
	///   - longitude: The coordinate's longitude, in degrees.
	func openMaps(latitude: Double, longitude: Double)
}

/// `MapsOpening` backed by `MKMapItem.openInMaps`. The only type that
/// knows how to turn a raw coordinate into an `MKMapItem` (§10.3.2).
///
/// §10.3.2 specified the now-deprecated `MKMapItem(placemark:)`; this
/// uses the iOS 26 replacement `MKMapItem(location:address:)`.
@MainActor
public struct SystemMapsOpener: MapsOpening {
	public init() {}

	public func openMaps(latitude: Double, longitude: Double) {
		let location = CLLocation(latitude: latitude, longitude: longitude)
		let mapItem = MKMapItem(location: location, address: nil)
		mapItem.openInMaps(launchOptions: nil)
	}
}
